<?php
ob_start();
session_start();
require __DIR__ . '/../backend/db_connect.php';

if (isset($_SESSION['user_id'])) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
$name = '';
$email = '';
$role = 'student';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    $confirm = $_POST['confirm'] ?? '';
    $role = $_POST['role'] ?? 'student';

    if ($name === '' || strlen($name) > 100) {
        $error = 'Enter your full name (up to 100 characters).';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 100) {
        $error = 'Enter a valid email address.';
    } elseif (strlen($password) < 8) {
        $error = 'Your password needs at least 8 characters.';
    } elseif ($password !== $confirm) {
        $error = 'The two passwords do not match.';
    } elseif (!in_array($role, ['student', 'adviser'], true)) {
        $error = 'Choose whether you are a student or an adviser.';
    } else {
        $check = $conn->prepare('SELECT user_id FROM users WHERE email = ?');
        $check->bind_param('s', $email);
        $check->execute();

        if ($check->get_result()->num_rows > 0) {
            $error = 'That email is already registered. Log in instead.';
        } else {
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $conn->prepare('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)');
            $stmt->bind_param('ssss', $name, $email, $hash, $role);

            if ($stmt->execute()) {
                // Advisers need a profile row so students can apply to them later
                if ($role === 'adviser') {
                    $newId = $conn->insert_id;
                    $profile = $conn->prepare('INSERT INTO adviser_profiles (adviser_id) VALUES (?)');
                    $profile->bind_param('i', $newId);
                    $profile->execute();
                }
                header('Location: login.php?registered=1');
                exit;
            }
            $error = 'We could not create your account. Try again.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Create account | AdviserLink</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="shell">
    <?php include '_panel.php'; ?>
    <main class="form-side">
      <div class="card">
        <h1>Create your account</h1>
        <p class="lede">It takes under a minute.</p>

        <?php if ($error): ?>
          <div class="alert error" role="alert"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <form method="POST" action="register.php">
          <div class="field">
            <label for="name">Full name</label>
            <input type="text" id="name" name="name" value="<?= htmlspecialchars($name) ?>" required autofocus>
          </div>
          <div class="field">
            <label for="email">Email</label>
            <input type="email" id="email" name="email" value="<?= htmlspecialchars($email) ?>" required>
          </div>
          <div class="field">
            <label for="password">Password</label>
            <input type="password" id="password" name="password" minlength="8" required>
            <p class="hint">At least 8 characters.</p>
          </div>
          <div class="field">
            <label for="confirm">Confirm password</label>
            <input type="password" id="confirm" name="confirm" minlength="8" required>
          </div>
          <fieldset>
            <legend>I am a</legend>
            <div class="choices">
              <label class="choice"><input type="radio" name="role" value="student" <?= $role === 'student' ? 'checked' : '' ?>> Student</label>
              <label class="choice"><input type="radio" name="role" value="adviser" <?= $role === 'adviser' ? 'checked' : '' ?>> Adviser</label>
            </div>
          </fieldset>
          <button type="submit">Create account</button>
        </form>

        <p class="switch">Already have an account? <a href="login.php">Log in</a></p>
      </div>
    </main>
  </div>
</body>
</html>
