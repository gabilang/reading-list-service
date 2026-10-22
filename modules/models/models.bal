# A reader's progress on a book.
public type ReadingStatus "TO_READ"|"READING"|"FINISHED";

# Payload used to add a book to a reader's list.
#
# + bookId - id of the book in bookstore-service
# + reader - the reader's name
public type ReadingListEntryInput record {|
    int bookId;
    string reader;
|};

# An entry in a reader's reading list.
#
# + id - unique identifier assigned by this service
# + status - the reader's progress on the book
public type ReadingListEntry record {|
    readonly int id;
    *ReadingListEntryInput;
    ReadingStatus status;
|};

# The subset of a bookstore-service book this service needs.
#
# + id - book id
# + title - book title
# + author - book author
public type Book record {|
    int id;
    string title;
    string author;
|};

# A reading-list entry together with the book details fetched from bookstore-service.
#
# + book - the book this entry refers to
public type EnrichedEntry record {|
    *ReadingListEntry;
    Book book;
|};

# Body returned by the service for error responses.
#
# + message - human-readable error message
public type ErrorResponse record {|
    string message;
|};

# Returned when a `ReadingListEntryInput` fails validation.
public type ValidationError distinct error;

# Validates a reading-list entry payload.
#
# + input - the payload to validate
# + return - a `ValidationError` describing the first failed rule, or `()` if the payload is valid
public isolated function validate(ReadingListEntryInput input) returns ValidationError? {
    if input.bookId <= 0 {
        return error ValidationError("bookId must be a positive integer");
    }
    if input.reader.trim().length() == 0 {
        return error ValidationError("reader must not be empty");
    }
}
