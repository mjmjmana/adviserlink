<?php
ob_start();
session_start();

if (!isset($_SESSION['user_id'])) {
    header('Location: login.php');
    exit;
}

$name = $_SESSION['name'];
$role = $_SESSION['role'];

$upcoming = [
    'student' => [
        ['Search advisers by keyword', 'Sprint 2'],
        ['Apply to an adviser', 'Sprint 2'],
        ['Book a consultation slot', 'Sprint 3'],
    ],
    'adviser' => [
        ['Set up your profile and availability', 'Sprint 2'],
        ['Review pending applications', 'Sprint 3'],
        ['Log consultation progress', 'Sprint 3'],
    ],
    'admin' => [
        ['Manage users', 'Sprint 3'],
        ['View reports', 'Sprint 3'],
    ],
];
$items = $upcoming[$role] ?? [];
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Dashboard | AdviserLink</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header class="topbar">
    <p class="brand">AdviserLink</p>
    <a href="logout.php">Log out</a>
  </header>
  <main class="page">
    <h1>Welcome, <?= htmlspecialchars($name) ?></h1>
    <span class="role-tag"><?= htmlspecialchars(ucfirst($role)) ?></span>
    <p>You are logged in. These features are being built in the next sprints:</p>
    <ul class="upcoming">
      <?php foreach ($items as [$label, $sprint]): ?>
        <li><?= htmlspecialchars($label) ?> <span><?= htmlspecialchars($sprint) ?></span></li>
      <?php endforeach; ?>
    </ul>
  </main>
</body>
</html>
