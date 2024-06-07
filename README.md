# Moeban

## Documentation for the Moeban Project

## Project Structure
The Moeban project is a JSON database system designed to store and manipulate data in JSON format.

## Main Functions

### `Moeban`
Defines a structure representing the JSON database. Includes methods to initialize the database, check if it exists, create it, read its content, and perform write and deletion operations.

#### Parameters
- `S`: Schema of the database, representing the structure of the stored data.
- `T`: Type of individual elements in the database.

#### Methods
- `init`: Initializes the database with a name, default data, and an allocator.
- `existsDataBase`: Checks if the database already exists.
- `createDataBase`: Creates the database with default data.
- `readDataBase`: Reads the content of the database.
- `parser`: Parses the database content and converts it into an easy-to-use structure.
- `compareById`: Compares two elements by their ID.
- `findById`: Finds an element by its ID in a specific field.
- `write`: Writes an element in a specific field.
- `writeMany`: Writes multiple elements in a specific field.
- `deleteOne`: Deletes an element by its ID in a specific field.
- `deleteMany`: Deletes elements based on a specified condition.

### `main`
The main function that runs the program. Performs various test operations on the database, including writing, finding, deleting, and writing multiple users.

#### Operations Performed
- Initializes the database with a schema and default data.
- Writes a user in the "items" field.
- Finds and displays information about the written user.
- Deletes the written user.
- Writes multiple users in the "others" field.
- Deletes users based on a specific property ("age").

## Usage Example
This file contains an example of how to use the Moeban database, showing how basic CRUD (Create, Read, Update, Delete) operations can be performed.

## Considerations
- Make sure Zig is installed and your development environment is correctly set up.
- This project uses the general-purpose memory manager `GeneralPurposeAllocator` to handle dynamic memory allocations.

---

```zig 
const Schema = struct { items: []User }; // Define your schema 
const default_data = \{ "items": [] }\; // Default data in JSON format

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const moeban = try Moeban(Schema, User).init("test.json", default_data, allocator);
```

### Writing Data
```zig
try moeban.write("items", .{.id = 1, .name = "John Doe", .age = 30 });
```

### Finding Data
```zig
const user = try moeban.findById("items", 1); 
defer allocator.free(user.data); 
std.debug.print("{}\n", .{user.item});
```

### Deleting Data
```zig 
try moeban.deleteOne("items", 1);
```

### Writing Multiple Users
```zig 
var users = std.ArrayList(User).init(allocator); 
defer users.deinit(); 

// Add users to the array...
try moeban.writeMany("others", users.items);
```

### Deleting Users Based on a Condition
```zig 
try moeban.deleteMany("others", "age", .{ .Number = 22 }); // or String = "22"
```

## Considerations
- Make sure Zig is installed and your development environment is correctly set up.
- This project uses the general-purpose memory manager `GeneralPurposeAllocator` to handle dynamic memory allocations.

- you can also use other memory allocators such as, `areana_allocator`, `page_allocator`, etc....

Don't forget to free the memory.
---
