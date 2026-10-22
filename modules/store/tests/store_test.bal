import ballerina/test;
import reading_list_service.models;

final models:ReadingListEntryInput duneEntry = {bookId: 1, reader: "Ada"};
final models:ReadingListEntryInput neuromancerEntry = {bookId: 2, reader: "Ada"};
final models:ReadingListEntryInput messiahEntry = {bookId: 3, reader: "Grace"};

ReadingList readingList = new;

@test:BeforeEach
function resetStore() {
    readingList = new;
}

@test:Config {groups: ["store"]}
function testAddAssignsIncrementingIdsAndDefaultsStatus() {
    models:ReadingListEntry first = readingList.add(duneEntry);
    models:ReadingListEntry second = readingList.add(neuromancerEntry);
    test:assertEquals(first.id, 1);
    test:assertEquals(second.id, 2);
    test:assertEquals(first.status, "TO_READ");
    test:assertEquals(readingList.count(), 2);
}

@test:Config {groups: ["store"]}
function testGetExistingEntry() returns error? {
    models:ReadingListEntry added = readingList.add(duneEntry);
    models:ReadingListEntry fetched = check readingList.get(added.id);
    test:assertEquals(fetched, added);
}

@test:Config {groups: ["store"]}
function testGetMissingEntryReturnsNotFound() {
    models:ReadingListEntry|NotFoundError result = readingList.get(42);
    if result !is NotFoundError {
        test:assertFail("expected NotFoundError");
    }
    test:assertEquals(result.message(), "reading list entry 42 not found");
}

@test:Config {groups: ["store"]}
function testListFiltersByReader() {
    _ = readingList.add(duneEntry);
    _ = readingList.add(neuromancerEntry);
    _ = readingList.add(messiahEntry);
    test:assertEquals(readingList.list("Ada").map(e => e.bookId), [1, 2]);
    test:assertEquals(readingList.list("Grace").map(e => e.bookId), [3]);
    test:assertEquals(readingList.list("Nobody"), []);
    test:assertEquals(readingList.list().length(), 3);
}

@test:Config {groups: ["store"]}
function testUpdateStatusOfExistingEntry() returns error? {
    models:ReadingListEntry added = readingList.add(duneEntry);
    models:ReadingListEntry updated = check readingList.updateStatus(added.id, "READING");
    test:assertEquals(updated.id, added.id);
    test:assertEquals(updated.status, "READING");
    test:assertEquals((check readingList.get(added.id)).status, "READING");
}

@test:Config {groups: ["store"]}
function testUpdateStatusOfMissingEntryReturnsNotFound() {
    test:assertTrue(readingList.updateStatus(7, "READING") is NotFoundError);
}

@test:Config {groups: ["store"]}
function testRemoveExistingEntry() {
    models:ReadingListEntry added = readingList.add(duneEntry);
    test:assertEquals(readingList.remove(added.id), ());
    test:assertEquals(readingList.count(), 0);
    test:assertTrue(readingList.get(added.id) is NotFoundError);
}

@test:Config {groups: ["store"]}
function testRemoveMissingEntryReturnsNotFound() {
    test:assertTrue(readingList.remove(99) is NotFoundError);
}
