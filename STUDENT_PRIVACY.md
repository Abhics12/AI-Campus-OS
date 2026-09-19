# Student privacy

- The global Directory is hidden/removed from the student interface.
- Students see only teachers/subjects assigned to their own section and workspace.
- No cross-workspace teacher/student information should be returned by the backend.
- Production queries must enforce this with authenticated user membership + section filters, not UI hiding alone.
