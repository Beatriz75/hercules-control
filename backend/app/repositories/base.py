class BaseRepository:
    """Marker base class for future persistence repositories.

    WEB-003 intentionally does not connect to a database. Concrete repositories
    will be added when persistence is implemented.
    """
