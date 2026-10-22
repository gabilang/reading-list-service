# reading-list-service

Tracks what a reader wants to read, is reading, or has finished. Backed by `bookstore-service`
for book details — a book must exist there before it can be added to a list, and a single-entry
lookup here calls out to it for the book's current title/author. Demonstrates one WSO2 Cloud
component calling another.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `port` | `9091` | Port this service listens on |
| `bookstoreServiceUrl` | `http://localhost:9090/books` | Base URL of bookstore-service's `/books` API |

On WSO2 Cloud, point `bookstoreServiceUrl` at bookstore-service's own endpoint URL for the
environment — its public URL if bookstore-service is public, or its organization-visibility URL
if it's only reachable from inside the organization's dataplane.
# reading-list-service
