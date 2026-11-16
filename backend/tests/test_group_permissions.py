import asyncio

import pytest
from fastapi import HTTPException

import db_setup
import main


class Result:
    def __init__(self, row=None):
        self.row = row

    def mappings(self):
        return self

    def first(self):
        return self.row


class Connection:
    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def execute(self, statement, params=None):
        query = str(statement)
        if "SELECT application_id FROM applications WHERE application_id = :a FOR UPDATE" in query:
            return Result((5,))
        if "SELECT a.application_id, a.student_id, a.adviser_id" in query:
            return Result({"application_id": 5, "student_id": 10, "adviser_id": 20,
                           "topic_brief": "Project topic", "status": "approved",
                           "student_name": "Student", "adviser_name": "Adviser"})
        if "SELECT g.student_id, g.application_id, a.adviser_id, a.status" in query:
            return Result({"student_id": 11, "application_id": 5, "adviser_id": 20, "status": "approved"})
        if "SELECT 1 FROM application_groups" in query:
            return Result(None)
        raise AssertionError(f"Unexpected query in permission test: {query}")


class Engine:
    def connect(self):
        return Connection()

    def begin(self):
        return Connection()


@pytest.mark.parametrize(
    "user",
    [
        {"user_id": 20, "role": "adviser", "name": "Adviser"},
        {"user_id": 11, "role": "student", "name": "Member"},
    ],
)
def test_non_leaders_cannot_invite_group_members(monkeypatch, user):
    monkeypatch.setattr(main, "engine", Engine())

    with pytest.raises(HTTPException) as error:
        main.invite_group_member(
            5,
            main.GroupInvitationIn(student_email="new.student@example.com"),
            user,
        )

    assert error.value.status_code == 403


@pytest.mark.parametrize(
    "user",
    [
        {"user_id": 20, "role": "adviser", "name": "Adviser"},
        {"user_id": 11, "role": "student", "name": "Member"},
    ],
)
def test_non_leaders_cannot_remove_group_members(monkeypatch, user):
    monkeypatch.setattr(main, "engine", Engine())

    with pytest.raises(HTTPException) as error:
        main.remove_group_member(99, user)

    assert error.value.status_code == 403


@pytest.mark.parametrize(
    "group_role, creates_leader_membership",
    [("leader", True), ("member", False)],
)
def test_approving_application_creates_group_leader_membership_for_leaders(
    monkeypatch, group_role, creates_leader_membership
):
    statements = []

    class ApprovalConnection(Connection):
        def execute(self, statement, params=None):
            query = str(statement)
            statements.append(query)
            if "SELECT max_capacity, current_advisee_count FROM adviser_profiles" in query:
                return Result((4, 0))
            if "SELECT a.student_id, a.status, u.student_group_role" in query:
                return Result((10, "pending", group_role))
            return Result()

    class ApprovalEngine:
        def begin(self):
            return ApprovalConnection()

    monkeypatch.setattr(main, "engine", ApprovalEngine())
    monkeypatch.setattr(main, "notify", lambda *_args, **_kwargs: None)

    result = main.decide_application(
        5,
        main.AppStatusIn(status="approved"),
        {"user_id": 20, "role": "adviser", "name": "Adviser"},
    )

    assert result["message"] == "Application approved."
    assert any("INSERT IGNORE INTO application_groups" in query for query in statements) is creates_leader_membership


def test_student_group_members_cannot_apply_to_advisers():
    with pytest.raises(HTTPException) as error:
        main.apply(
            main.ApplicationIn(adviser_id=20, topic_brief="A valid research topic"),
            {"user_id": 11, "role": "student", "student_group_role": "member", "name": "Member"},
        )

    assert error.value.status_code == 403
    assert "group leaders" in error.value.detail


def test_student_group_leaders_need_a_complete_title_before_applying():
    with pytest.raises(HTTPException) as error:
        main.apply(
            main.ApplicationIn(adviser_id=20, topic_brief="A valid research topic"),
            {
                "user_id": 10,
                "role": "student",
                "student_group_role": "leader",
                "name": "Leader",
                "thesis_title": "",
            },
        )

    assert error.value.status_code == 409
    assert "complete thesis or capstone title" in error.value.detail


def test_student_group_members_cannot_join_adviser_waitlist():
    with pytest.raises(HTTPException) as error:
        main.join_waitlist(
            main.WaitlistIn(adviser_id=20, topic_brief="A valid research topic"),
            {"user_id": 11, "role": "student", "student_group_role": "member"},
        )

    assert error.value.status_code == 403
    assert "group leaders" in error.value.detail


def test_topic_match_uses_related_keywords_not_exact_phrases():
    score, matched = main.topic_match(
        "Machine learning for sustainable agriculture",
        "Research on agriculture and machine learning",
    )

    assert score == 3
    assert matched == ["agriculture", "learning", "machine"]


def test_topic_match_accepts_partial_keywords_and_member_emails():
    score, matched = main.topic_match("maria@isu", "Maria Santos maria.santos@isu.edu.ph")

    assert score == 2
    assert matched == ["isu", "maria"]


def test_member_group_search_returns_groups_matching_saved_project_title():
    group = {
        "topic_brief": "An IoT based smart agriculture monitoring system",
        "leader_name": "A group leader",
        "leader_email": "leader@example.com",
        "adviser_name": "Research Adviser",
    }

    match = main.match_group_search(
        "network monitoring",
        "Smart IoT crop monitoring for sustainable agriculture",
        group,
    )

    assert match is not None
    assert match["matched_by"] == "project topic"
    assert match["match_score"] >= 6
    assert {"iot", "monitoring", "smart"}.issubset(set(match["matched_topics"]))


def test_member_group_search_still_finds_leader_name_without_title_overlap():
    group = {
        "topic_brief": "A completely unrelated research project",
        "leader_name": "Maria Santos",
        "leader_email": "maria@example.com",
        "adviser_name": "Research Adviser",
    }

    match = main.match_group_search("Maria", "Student research on agriculture", group)

    assert match is not None
    assert match["matched_by"] == "group leader"
    assert "maria" in match["matched_topics"]


def test_member_group_directory_includes_new_leader_without_adviser(monkeypatch):
    class Rows:
        def mappings(self):
            return self

        def all(self):
            return [{
                "application_id": None,
                "application_status": None,
                "topic_brief": "Smart agriculture monitoring project",
                "leader_id": 25,
                "leader_name": "New Leader",
                "leader_email": "leader@example.com",
                "leader_profile_photo": None,
                "adviser_name": None,
                "member_count": 1,
                "reserved_count": 0,
                "request_status": None,
                "has_pending_invitation": 0,
                "has_pending_request": 0,
                "has_any_pending_invitation": 0,
            }]

    class DirectoryConnection(Connection):
        def execute(self, statement, params=None):
            query = str(statement)
            if (
                "FROM applications WHERE student_id" in query
                or "FROM application_groups WHERE student_id" in query
                or "FROM student_group_requests WHERE member_id" in query
            ):
                return Result(None)
            if "FROM users leader" in query:
                assert "LEFT JOIN applications a" in query
                assert "COALESCE(leader.student_group_role, 'leader') = 'leader'" in query
                return Rows()
            raise AssertionError(f"Unexpected directory query: {query}")

    class DirectoryEngine:
        def connect(self):
            return DirectoryConnection()

    monkeypatch.setattr(main, "engine", DirectoryEngine())
    member = {
        "user_id": 11,
        "role": "student",
        "student_group_role": "member",
        "thesis_title": "Smart agriculture crop monitoring",
    }

    results = main.available_groups("leader", member)

    assert len(results) == 1
    assert results[0]["leader_id"] == 25
    assert results[0]["application_id"] is None
    assert results[0]["adviser_name"] is None


@pytest.mark.parametrize(
    "blocked_query, expected_detail",
    [
        ("FROM applications WHERE student_id", "adviser application"),
        ("FROM application_groups WHERE student_id", "project group"),
    ],
)
def test_member_cannot_browse_or_request_groups_when_already_attached(
    monkeypatch, blocked_query, expected_detail
):
    class EligibilityConnection(Connection):
        def execute(self, statement, params=None):
            query = str(statement)
            if "FROM applications WHERE student_id" in query:
                return Result((1,) if blocked_query in query else None)
            if blocked_query in query:
                return Result((1,))
            raise AssertionError(f"Unexpected eligibility query: {query}")

    class EligibilityEngine:
        def connect(self):
            return EligibilityConnection()

        def begin(self):
            return EligibilityConnection()

    monkeypatch.setattr(main, "engine", EligibilityEngine())
    member = {
        "user_id": 11,
        "role": "student",
        "student_group_role": "member",
        "name": "Member",
        "thesis_title": "A complete member research project",
    }

    with pytest.raises(HTTPException) as error:
        main.available_groups("keyword", member)

    assert error.value.status_code == 409
    assert expected_detail in error.value.detail
    with pytest.raises(HTTPException) as request_error:
        main.request_group_membership(5, member)

    assert request_error.value.status_code == 409
    assert expected_detail in request_error.value.detail


def test_member_cannot_request_a_second_group_while_another_request_is_pending():
    class PendingRequestConnection(Connection):
        def execute(self, statement, params=None):
            query = str(statement)
            if "FROM group_join_requests WHERE student_id" in query:
                return Result((1,))
            raise AssertionError(f"Unexpected pending-request query: {query}")

    with pytest.raises(HTTPException) as error:
        main.ensure_no_pending_group_commitment(PendingRequestConnection(), 11)

    assert error.value.status_code == 409
    assert "pending request" in error.value.detail


def test_saving_account_without_research_interests_keeps_existing_value(monkeypatch):
    statements = []

    class AccountConnection(Connection):
        def execute(self, statement, params=None):
            statements.append((str(statement), params))
            return Result()

    class AccountEngine:
        def begin(self):
            return AccountConnection()

    monkeypatch.setattr(main, "engine", AccountEngine())
    result = main.update_me(
        main.MeIn(name="Student Name", contact_number=""),
        {
            "user_id": 11,
            "role": "student",
            "research_interests": "sustainable agriculture",
        },
    )

    assert "research_interests = :i" not in statements[0][0]
    assert result["research_interests"] == "sustainable agriculture"


def test_saving_complete_thesis_title_updates_student_profile(monkeypatch):
    statements = []

    class AccountConnection(Connection):
        def execute(self, statement, params=None):
            statements.append((str(statement), params))
            return Result()

    class AccountEngine:
        def begin(self):
            return AccountConnection()

    monkeypatch.setattr(main, "engine", AccountEngine())
    title = "A complete capstone title for profile matching"
    result = main.update_me(
        main.MeIn(name="Student Name", thesis_title=title),
        {"user_id": 11, "role": "student", "thesis_title": None},
    )

    assert "thesis_title = :t" in statements[0][0]
    assert statements[0][1]["t"] == title
    assert result["thesis_title"] == title


def test_group_members_can_view_document_versions(monkeypatch):
    class VersionRows:
        def mappings(self):
            return self

        def all(self):
            return [{"version_id": 8, "filename": "proposal-v2.pdf"}]

    class VersionConnection:
        def __enter__(self):
            return self

        def __exit__(self, *_):
            return False

        def execute(self, statement, params=None):
            query = str(statement)
            if "SELECT application_id FROM documents" in query:
                return Result({"application_id": 5})
            if "SELECT a.application_id, a.student_id, a.adviser_id" in query:
                return Result({
                    "application_id": 5,
                    "student_id": 10,
                    "adviser_id": 20,
                    "topic_brief": "Project topic",
                    "status": "approved",
                    "student_name": "Student",
                    "adviser_name": "Adviser",
                })
            if "SELECT 1 FROM application_groups" in query:
                return Result((11,))
            if "FROM document_versions v" in query:
                return VersionRows()
            raise AssertionError(f"Unexpected document-version query: {query}")

    class VersionEngine:
        def connect(self):
            return VersionConnection()

    monkeypatch.setattr(main, "engine", VersionEngine())

    versions = main.get_document_versions(
        8,
        {"user_id": 11, "role": "student", "name": "Group member"},
    )

    assert versions == [{"version_id": 8, "filename": "proposal-v2.pdf"}]


def test_group_members_cannot_upload_document_versions(monkeypatch):
    class VersionConnection:
        def __enter__(self):
            return self

        def __exit__(self, *_):
            return False

        def execute(self, statement, params=None):
            query = str(statement)
            if "SELECT application_id FROM documents" in query:
                return Result({"application_id": 5})
            if "SELECT a.application_id, a.student_id, a.adviser_id" in query:
                return Result({
                    "application_id": 5,
                    "student_id": 10,
                    "adviser_id": 20,
                    "topic_brief": "Project topic",
                    "status": "approved",
                    "student_name": "Student",
                    "adviser_name": "Adviser",
                })
            if "SELECT 1 FROM application_groups" in query:
                return Result(None if "is_leader = 1" in query else (11,))
            raise AssertionError(f"Unexpected document-version query: {query}")

    class VersionEngine:
        def connect(self):
            return VersionConnection()

    class Upload:
        filename = "proposal.pdf"

    monkeypatch.setattr(main, "engine", VersionEngine())

    with pytest.raises(HTTPException) as error:
        asyncio.run(main.upload_document_version(
            8,
            Upload(),
            None,
            {"user_id": 11, "role": "student", "name": "Group member"},
        ))

    assert error.value.status_code == 403
    assert "group leader" in error.value.detail


def test_existing_profile_backfill_preserves_titles_and_uses_group_sources():
    statements = []

    class MigrationConnection:
        def execute(self, statement, params=None):
            statements.append(str(statement))
            return Result()

    db_setup.backfill_existing_student_profiles(MigrationConnection())

    assert len(statements) == 5
    assert "a.topic_brief" in statements[0]
    assert "u.thesis_title IS NULL OR CHAR_LENGTH(TRIM(u.thesis_title)) < 10" in statements[0]
    assert "g.is_leader = 0" in statements[1]
    assert "g.is_leader = 1" in statements[1]
    assert "leader.thesis_title" in statements[2]
    assert "student_group_requests" in statements[3]
    assert "student_group_requests" in statements[4]


def test_legacy_user_without_title_is_not_forced_through_setup():
    legacy_user = main.public_user({
        "user_id": 41,
        "name": "Legacy Student",
        "email": "legacy@example.com",
        "role": "student",
        "title_setup_required": 0,
    })

    assert legacy_user["title_setup_required"] is False


def test_adviser_registration_requires_a_department():
    with pytest.raises(ValueError, match="Choose your department"):
        main.RegisterIn(
            name="Adviser Name",
            email="adviser@example.com",
            password="secure-pass-123",
            confirm_password="secure-pass-123",
            role="adviser",
        )


def test_adviser_registration_accepts_a_known_department():
    registration = main.RegisterIn(
        name="Adviser Name",
        email="adviser@example.com",
        password="secure-pass-123",
        confirm_password="secure-pass-123",
        role="adviser",
        department="Computer Science",
    )

    assert registration.department == "Computer Science"


def test_student_registration_does_not_require_an_adviser_department():
    registration = main.RegisterIn(
        name="Student Name",
        email="student@example.com",
        password="secure-pass-123",
        confirm_password="secure-pass-123",
        role="student",
        department=None,
    )

    assert registration.department is None


def test_adviser_card_exposes_department_from_profile_or_legacy_tag():
    profile = {
        "adviser_id": 25,
        "name": "Adviser",
        "email": "adviser@example.com",
        "specialization_tags": "Department: Computer Science, AI",
        "certifications": "",
        "max_capacity": 5,
        "current_advisee_count": 0,
    }

    assert main.adviser_card(profile)["department"] == "Computer Science"
    profile["department"] = "Information Systems"
    assert main.adviser_card(profile)["department"] == "Information Systems"
