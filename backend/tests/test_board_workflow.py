import asyncio
from io import BytesIO

import pytest
from fastapi import HTTPException, UploadFile

import main
from board_workflow import can_comment_on_task, can_manage_application, can_transition_task


def test_student_can_advance_only_to_working_and_review():
    assert can_transition_task("student", "todo", "in_progress")
    assert can_transition_task("student", "in_progress", "review")
    assert not can_transition_task("student", "todo", "review")
    assert not can_transition_task("student", "review", "done")
    assert not can_transition_task("student", "done", "review")


def test_adviser_can_finish_or_return_submitted_work():
    assert can_transition_task("adviser", "review", "done")
    assert can_transition_task("adviser", "review", "in_progress")
    assert not can_transition_task("adviser", "todo", "in_progress")
    assert not can_transition_task("adviser", "in_progress", "review")
    assert not can_transition_task("adviser", "done", "review")


def test_only_leaders_can_manage_the_shared_project():
    assert can_manage_application("student", 10, 10, False)
    assert can_manage_application("student", 11, 10, True)
    assert not can_manage_application("student", 12, 10, False)
    assert can_manage_application("adviser", 20, 10, False)


def test_only_advisers_and_group_leaders_can_reply_to_task_comments():
    assert can_comment_on_task("adviser", False)
    assert can_comment_on_task("student", True)
    assert not can_comment_on_task("student", False)
    assert not can_comment_on_task("admin", False)


def test_task_comments_accept_multipart_attachments():
    request_body = main.app.openapi()["paths"]["/api/tasks/{task_id}/comments"]["post"]["requestBody"]
    assert "multipart/form-data" in request_body["content"]


def test_board_file_upload_requires_a_task():
    with pytest.raises(HTTPException) as error:
        asyncio.run(main.upload_document(
            application_id=1,
            file=None,
            booking_id=None,
            category="todo",
            task_id=None,
            user={"user_id": 1, "role": "student"},
        ))

    assert error.value.status_code == 400
    assert error.value.detail == "Choose a task before uploading board work."


def test_comment_file_upload_is_saved_and_invalid_text_is_removed(tmp_path, monkeypatch):
    monkeypatch.setattr(main, "UPLOAD_DIR", str(tmp_path))
    valid_upload = UploadFile(filename="draft.txt", file=BytesIO(b"completed draft"))

    name, stored, size, path = asyncio.run(main.store_uploaded_file(valid_upload))

    assert name == "draft.txt"
    assert size == len(b"completed draft")
    assert (tmp_path / stored).read_bytes() == b"completed draft"
    assert path == str(tmp_path / stored)

    invalid_upload = UploadFile(filename="invalid.txt", file=BytesIO(b"\x00binary"))
    with pytest.raises(HTTPException) as error:
        asyncio.run(main.store_uploaded_file(invalid_upload))

    assert error.value.status_code == 400
    assert sorted(file.name for file in tmp_path.iterdir()) == [stored]
