import reading_list_service.models;

# Returned when no reading-list entry exists for a given id.
public type NotFoundError distinct error;

# Thread-safe, in-memory reading-list repository.
public isolated class ReadingList {
    private final table<models:ReadingListEntry> key(id) entries = table [];
    private int nextId = 1;

    # Adds an entry, defaulting its status to TO_READ.
    #
    # + input - the entry details
    # + return - the stored entry
    public isolated function add(models:ReadingListEntryInput input) returns models:ReadingListEntry {
        lock {
            models:ReadingListEntry entry = {id: self.nextId, status: "TO_READ", ...input.clone()};
            self.entries.add(entry);
            self.nextId += 1;
            return entry.clone();
        }
    }

    # Looks up an entry by id.
    #
    # + id - the entry id
    # + return - a copy of the entry, or a `NotFoundError`
    public isolated function get(int id) returns models:ReadingListEntry|NotFoundError {
        lock {
            models:ReadingListEntry? entry = self.entries[id];
            if entry is () {
                return notFound(id);
            }
            return entry.clone();
        }
    }

    # Lists entries, optionally filtered by reader.
    #
    # + reader - reader to filter by, or `()` for everyone
    # + return - the matching entries ordered by id
    public isolated function list(string? reader = ()) returns models:ReadingListEntry[] {
        lock {
            models:ReadingListEntry[] matches = from models:ReadingListEntry entry in self.entries
                where reader is () || entry.reader == reader
                order by entry.id
                select entry;
            return matches.clone();
        }
    }

    # Updates an entry's status.
    #
    # + id - the entry id
    # + status - the new status
    # + return - the updated entry, or a `NotFoundError`
    public isolated function updateStatus(int id, models:ReadingStatus status) returns models:ReadingListEntry|NotFoundError {
        lock {
            models:ReadingListEntry? existing = self.entries[id];
            if existing is () {
                return notFound(id);
            }
            models:ReadingListEntry updated = {id: existing.id, bookId: existing.bookId, reader: existing.reader, status};
            self.entries.put(updated);
            return updated.clone();
        }
    }

    # Removes an entry.
    #
    # + id - the entry id
    # + return - a `NotFoundError` if no such entry exists
    public isolated function remove(int id) returns NotFoundError? {
        lock {
            if self.entries.removeIfHasKey(id) is () {
                return notFound(id);
            }
        }
    }

    # Returns the number of stored entries.
    #
    # + return - the entry count
    public isolated function count() returns int {
        lock {
            return self.entries.length();
        }
    }
}

isolated function notFound(int id) returns NotFoundError => error NotFoundError(string `reading list entry ${id} not found`);
