def can_transition_task(role: str, current: str, target: str) -> bool:
    if role == "adviser":
        return current == "review" and target in ("in_progress", "done")
    return (current, target) in (("todo", "in_progress"), ("in_progress", "review"))


def can_manage_application(role: str, user_id: int, student_id: int, is_group_leader: bool) -> bool:
    return role == "adviser" or (role == "student" and (user_id == student_id or is_group_leader))


def can_comment_on_task(role: str, is_group_leader: bool) -> bool:
    return role == "adviser" or (role == "student" and is_group_leader)
