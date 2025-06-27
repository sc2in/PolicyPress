# Tera Template Engine Interpreter for Zig 0.14.1

A complete implementation of the Tera template engine using only Zig 0.14.1 and its standard library. This interpreter provides all the core features of Tera templates including variable interpolation, control structures, template inheritance, filters, and more.

## Features

- **Variable Interpolation**: `{{ variable }}`
- **Comments**: `{# comment #}`
- **Control Structures**: 
  - Conditionals: `{% if %}`, `{% elif %}`, `{% else %}`, `{% endif %}`
  - Loops: `{% for item in list %}`, `{% endfor %}`
  - Blocks: `{% block name %}`, `{% endblock %}`
- **Template Inheritance**: `{% extends "base.html" %}`
- **Includes**: `{% include "template.html" %}`
- **Variable Assignment**: `{% set var = value %}`
- **Filters**: `{{ variable | filter }}` with 20+ built-in filters
- **Complex Expressions**: Mathematical and logical operations
- **Context Management**: JSON-compatible data structures
- **Memory Safe**: Proper allocation and deallocation handling

## Project Structure

```
├── tera_main.zig     # Main Tera engine and API
├── lexer.zig         # Tokenizer for template syntax
├── parser.zig        # AST parser and template structure
├── context.zig       # Context and value management
├── renderer.zig      # Template renderer and evaluator
├── filters.zig       # Built-in filters implementation
├── example.zig       # Comprehensive usage examples
├── build.zig         # Build configuration
└── README.md         # This file
```

## Quick Start

### Building the Project

```bash
# Build the main executable
zig build

# Run the example
zig build run

# Run tests
zig build test
```

### Basic Usage

```zig
const std = @import("std");
const tera = @import("tera_main.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Tera engine
    var engine = tera.Tera.init(allocator);
    defer engine.deinit();

    // Add a template
    try engine.addTemplate("hello", "Hello, {{ name }}! You have {{ count }} messages.");

    // Create context
    var ctx = tera.context.Context.init(allocator);
    defer ctx.deinit();

    try ctx.set("name", tera.context.Value{ .string = "World" });
    try ctx.set("count", tera.context.Value{ .number = 42 });

    // Render template
    const result = try engine.render("hello", ctx);
    defer allocator.free(result);

    std.debug.print("Result: {s}\n", .{result});
    // Output: Result: Hello, World! You have 42 messages.
}
```

## Template Syntax

### Variables

```html
{{ variable }}
{{ object.property }}
{{ array.0 }}
```

### Conditionals

```html
{% if user.is_admin %}
    <p>Admin panel</p>
{% elif user.is_logged_in %}
    <p>User dashboard</p>
{% else %}
    <p>Please log in</p>
{% endif %}
```

### Loops

```html
{% for item in items %}
    <li>{{ loop.index }}: {{ item.name }}</li>
{% endfor %}
```

### Filters

```html
{{ text | upper }}
{{ number | round(2) }}
{{ array | join(", ") }}
{{ value | default("N/A") }}
```

### Template Inheritance

Base template (`base.html`):
```html
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}Default{% endblock %}</title>
</head>
<body>
    {% block content %}{% endblock %}
</body>
</html>
```

Child template:
```html
{% extends "base.html" %}

{% block title %}My Page{% endblock %}

{% block content %}
    <h1>Welcome!</h1>
{% endblock %}
```

## Built-in Filters

### String Filters
- `upper` - Convert to uppercase
- `lower` - Convert to lowercase  
- `capitalize` - Capitalize first letter
- `title` - Title case
- `trim` - Remove whitespace
- `length` - Get length
- `wordcount` - Count words
- `replace(from, to)` - Replace substring
- `truncate(len, suffix)` - Truncate string
- `urlencode` - URL encode

### Number Filters
- `round(precision)` - Round number
- `abs` - Absolute value
- `int` - Convert to integer
- `float` - Convert to float

### Array Filters
- `first` - Get first element
- `last` - Get last element
- `join(separator)` - Join elements
- `reverse` - Reverse order
- `sort` - Sort elements
- `unique` - Remove duplicates

### Utility Filters
- `default(value)` - Default if falsy
- `escape` - HTML escape
- `safe` - Mark as safe
- `json` - Convert to JSON
- `date(format)` - Format date

## Context and Data Types

The context system supports various data types:

```zig
// String
try ctx.set("name", tera.context.Value{ .string = "John" });

// Number
try ctx.set("age", tera.context.Value{ .number = 30 });

// Boolean
try ctx.set("active", tera.context.Value{ .boolean = true });

// Array
var items = std.ArrayList(tera.context.Value).init(allocator);
try items.append(tera.context.Value{ .string = "item1" });
try ctx.set("items", tera.context.Value{ .array = items });

// Object
var user = tera.context.Context.init(allocator);
try user.set("name", tera.context.Value{ .string = "Alice" });
try ctx.set("user", tera.context.Value{ .object = user });

// From JSON
var ctx = try tera.context.Context.fromJson(allocator, json_string);
```

## Advanced Features

### Custom Filters

```zig
fn customFilter(allocator: Allocator, value: context.Value, args: []const context.Value) !context.Value {
    // Your filter logic here
    return try value.clone(allocator);
}

try engine.registerFilter("custom", customFilter);
```

### Template Includes

```html
<!-- header.html -->
<header>
    <h1>{{ site_name }}</h1>
</header>

<!-- main.html -->
{% include "header.html" %}
<main>Content here</main>
```

### Loop Variables

```html
{% for item in items %}
    Index: {{ loop.index }}
    First: {{ loop.first }}
    Last: {{ loop.last }}
    Length: {{ loop.length }}
{% endfor %}
```

## Error Handling

The interpreter provides comprehensive error handling:

- `ParseError` - Template syntax errors
- `RenderError` - Runtime evaluation errors
- `TemplateNotFound` - Missing template files
- `VariableNotFound` - Undefined variables
- `FilterNotFound` - Unknown filters
- `OutOfMemory` - Memory allocation failures

## Performance Characteristics

- **Memory Efficient**: Proper allocation tracking and cleanup
- **Fast Parsing**: Single-pass lexer and recursive descent parser
- **Optimized Rendering**: Minimal allocations during evaluation
- **Scalable**: Handles complex nested templates and large data sets

## Testing

The project includes comprehensive tests for all modules:

```bash
# Run all tests
zig build test

# Run specific module tests
zig build test-lexer
zig build test-parser
zig build test-context
zig build test-renderer
zig build test-filters
```

## Compatibility

- **Zig Version**: 0.14.1
- **Dependencies**: None (uses only Zig standard library)
- **Platform**: Cross-platform (Windows, macOS, Linux)
- **Memory**: Manual memory management with allocators

## Example Output

When you run the example program, you'll see output demonstrating:

1. Basic variable interpolation
2. Conditional rendering
3. Loop iteration with complex data
4. Filter transformations
5. Template inheritance
6. Complex nested data structures
7. JSON context integration

## Contributing

This implementation demonstrates the core concepts of template engines and can be extended with additional features:

- More built-in filters
- Macro support
- Custom tag extensions
- Template caching
- Performance optimizations

## License

This project is provided as an educational example for implementing template engines in Zig. Feel free to use and modify as needed.