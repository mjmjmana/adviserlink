<?php
ob_start();
session_start();
require __DIR__ . '/../backend/db_connect.php';

if (isset($_SESSION['user_id'])) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
$notice = isset($_GET['registered']) ? 'Account created. Log in to continue.' : '';
$email = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';

    $stmt = $conn->prepare('SELECT user_id, name, password, role FROM users WHERE email = ?');
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();

    if ($user && password_verify($password, $user['password'])) {
        session_regenerate_id(true);
        $_SESSION['user_id'] = $user['user_id'];
        $_SESSION['name'] = $user['name'];
        $_SESSION['role'] = $user['role'];
        header('Location: dashboard.php');
        exit;
    }
    $error = 'Incorrect email or password.';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Log in | AdviserLink</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="shell">
    <?php include '_panel.php'; ?>
    <main class="form-side">
      <div class="card">
        <h1>Log in</h1>
        <p class="lede">Use the email and password you registered with.</p>

        <?php if ($notice): ?>
          <div class="alert ok" role="status"><?= htmlspecialchars($notice) ?></div>
        <?php endif; ?>
        <?php if ($error): ?>
          <div class="alert error" role="alert"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <form method="POST" action="login.php">
          <div class="field">
            <label for="email">Email</label>
            <input type="email" id="email" name="email" value="<?= htmlspecialchars($email) ?>" required autofocus>
          </div>
          <div class="field">
            <label for="password">Password</label>
            <input type="password" id="password" name="password" required>
          </div>
          <button type="submit">Log in</button>
        </form>

        <p class="switch">No account yet? <a href="register.php">Create one</a></p>
      </div>
    </main>
  </div>
</body>
</html>
