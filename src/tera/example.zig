//! Comprehensive example demonstrating the Tera interpreter
//! This file shows various features and usage patterns

const std = @import("std");
const tera = @import("tera.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const allocator = arena.allocator();

    std.debug.print("=== Tera Template Engine Demo ===\n\n", .{});

    // Initialize Tera engine
    var engine = tera.Tera.init(allocator);
    defer engine.deinit();

    // Example 1: Basic variable interpolation
    try example1_basic_variables(&engine, allocator);

    // Example 2: Conditionals
    try example2_conditionals(&engine, allocator);

    // Example 3: Loops
    try example3_loops(&engine, allocator);

    // Example 4: Filters
    try example4_filters(&engine, allocator);

    // Example 5: Template inheritance
    try example5_inheritance(&engine, allocator);

    // Example 6: Complex data structures
    try example6_complex_data(&engine, allocator);

    // Example 7: Custom context
    try example7_custom_context(&engine, allocator);
}

/// Example 1: Basic variable interpolation
fn example1_basic_variables(engine: *tera.Tera, allocator: std.mem.Allocator) !void {
    std.debug.print("1. Basic Variable Interpolation\n", .{});
    std.debug.print("--------------------------------\n", .{});

    const template_content =
        \\Hello, {{ name }}!
        \\You are {{ age }} years old.
        \\Your email is {{ email }}.
        \\Welcome to {{ site_name }}!
    ;

    try engine.addTemplate("basic", template_content);

    var ctx = tera.context.Context.init(allocator);
    defer ctx.deinit();

    try ctx.set("name", tera.context.Value{ .string = "Alice" });
    try ctx.set("age", tera.context.Value{ .number = 30 });
    try ctx.set("email", tera.context.Value{ .string = "alice@example.com" });
    try ctx.set("site_name", tera.context.Value{ .string = "Zig Templates" });

    const result = try engine.render("basic", ctx);
    defer allocator.free(result);

    std.debug.print("{s}\n\n", .{result});
}

/// Example 2: Conditionals
fn example2_conditionals(engine: *tera.Tera, allocator: std.mem.Allocator) !void {
    std.debug.print("2. Conditional Statements\n", .{});
    std.debug.print("-------------------------\n", .{});

    const template_content =
        \\{% if user.is_admin %}
        \\<h1>Admin Dashboard</h1>
        \\<p>Welcome, administrator {{ user.name }}!</p>
        \\{% elif user.is_logged_in %}
        \\<h1>User Dashboard</h1>
        \\<p>Hello, {{ user.name }}!</p>
        \\{% else %}
        \\<h1>Please Log In</h1>
        \\<p>You need to log in to access this page.</p>
        \\{% endif %}
        \\
        \\{% if user.notifications > 0 %}
        \\<div class="alert">You have {{ user.notifications }} new messages!</div>
        \\{% endif %}
    ;

    try engine.addTemplate("conditional", template_content);

    // Test case 1: Admin user
    var ctx1 = tera.context.Context.init(allocator);
    defer ctx1.deinit();

    var user1 = tera.context.Context.init(allocator);
    defer user1.deinit();
    try user1.set("name", tera.context.Value{ .string = "Bob" });
    try user1.set("is_admin", tera.context.Value{ .boolean = true });
    try user1.set("is_logged_in", tera.context.Value{ .boolean = true });
    try user1.set("notifications", tera.context.Value{ .number = 5 });

    try ctx1.set("user", tera.context.Value{ .object = user1 });

    const result1 = try engine.render("conditional", ctx1);
    defer allocator.free(result1);

    std.debug.print("Admin user:\n{s}\n", .{result1});

    // Test case 2: Regular user
    var ctx2 = tera.context.Context.init(allocator);
    defer ctx2.deinit();

    var user2 = tera.context.Context.init(allocator);
    defer user2.deinit();
    try user2.set("name", tera.context.Value{ .string = "Carol" });
    try user2.set("is_admin", tera.context.Value{ .boolean = false });
    try user2.set("is_logged_in", tera.context.Value{ .boolean = true });
    try user2.set("notifications", tera.context.Value{ .number = 0 });

    try ctx2.set("user", tera.context.Value{ .object = user2 });

    const result2 = try engine.render("conditional", ctx2);
    defer allocator.free(result2);

    std.debug.print("Regular user:\n{s}\n\n", .{result2});
}

/// Example 3: Loops
fn example3_loops(engine: *tera.Tera, allocator: std.mem.Allocator) !void {
    std.debug.print("3. Loop Statements\n", .{});
    std.debug.print("------------------\n", .{});

    const template_content =
        \\<h2>Product List</h2>
        \\{% if products %}
        \\<ul>
        \\{% for product in products %}
        \\  <li class="{% if loop.first %}first{% endif %}{% if loop.last %} last{% endif %}">
        \\    {{ loop.index }}. {{ product.name }} - ${{ product.price }}
        \\    {% if product.on_sale %}<span class="sale">ON SALE!</span>{% endif %}
        \\  </li>
        \\{% endfor %}
        \\</ul>
        \\<p>Total products: {{ products | length }}</p>
        \\{% else %}
        \\<p>No products available.</p>
        \\{% endif %}
    ;

    try engine.addTemplate("loop", template_content);

    var ctx = tera.context.Context.init(allocator);
    defer ctx.deinit();

    // Create products array
    var products = std.ArrayList(tera.context.Value).init(allocator);
    defer products.deinit();

    // Product 1
    var product1 = tera.context.Context.init(allocator);
    defer product1.deinit();
    try product1.set("name", tera.context.Value{ .string = "Laptop" });
    try product1.set("price", tera.context.Value{ .number = 999.99 });
    try product1.set("on_sale", tera.context.Value{ .boolean = true });
    try products.append(tera.context.Value{ .object = product1 });

    // Product 2
    var product2 = tera.context.Context.init(allocator);
    defer product2.deinit();
    try product2.set("name", tera.context.Value{ .string = "Mouse" });
    try product2.set("price", tera.context.Value{ .number = 29.99 });
    try product2.set("on_sale", tera.context.Value{ .boolean = false });
    try products.append(tera.context.Value{ .object = product2 });

    // Product 3
    var product3 = tera.context.Context.init(allocator);
    defer product3.deinit();
    try product3.set("name", tera.context.Value{ .string = "Keyboard" });
    try product3.set("price", tera.context.Value{ .number = 79.99 });
    try product3.set("on_sale", tera.context.Value{ .boolean = true });
    try products.append(tera.context.Value{ .object = product3 });

    try ctx.set("products", tera.context.Value{ .array = products });

    const result = try engine.render("loop", ctx);
    defer allocator.free(result);

    std.debug.print("{s}\n\n", .{result});
}

/// Example 4: Filters
fn example4_filters(engine: *tera.Tera, allocator: std.mem.Allocator) !void {
    std.debug.print("4. Template Filters\n", .{});
    std.debug.print("-------------------\n", .{});

    const template_content =
        \\<h2>Filter Examples</h2>
        \\<p>Original: "{{ text }}"</p>
        \\<p>Upper: "{{ text | upper }}"</p>
        \\<p>Lower: "{{ text | lower }}"</p>
        \\<p>Title: "{{ text | title }}"</p>
        \\<p>Length: {{ text | length }}</p>
        \\<p>Word Count: {{ text | wordcount }}</p>
        \\<p>Truncated: "{{ text | truncate(20) }}"</p>
        \\<p>Replaced: "{{ text | replace("World", "Zig") }}"</p>
        \\
        \\<h3>Number Filters</h3>
        \\<p>Number: {{ number }}</p>
        \\<p>Rounded: {{ number | round(2) }}</p>
        \\<p>Absolute: {{ negative | abs }}</p>
        \\<p>Integer: {{ number | int }}</p>
        \\
        \\<h3>Array Filters</h3>
        \\<p>Numbers: {{ numbers | join(", ") }}</p>
        \\<p>First: {{ numbers | first }}</p>
        \\<p>Last: {{ numbers | last }}</p>
        \\<p>Reversed: {{ numbers | reverse | join(" -> ") }}</p>
        \\<p>Sorted: {{ numbers | sort | join(", ") }}</p>
    ;

    try engine.addTemplate("filters", template_content);

    var ctx = tera.context.Context.init(allocator);
    defer ctx.deinit();

    try ctx.set("text", tera.context.Value{ .string = "Hello World! This is a test." });
    try ctx.set("number", tera.context.Value{ .number = 3.14159 });
    try ctx.set("negative", tera.context.Value{ .number = -42.5 });

    // Create numbers array
    var numbers = std.ArrayList(tera.context.Value).init(allocator);
    defer numbers.deinit();
    try numbers.append(tera.context.Value{ .number = 3 });
    try numbers.append(tera.context.Value{ .number = 1 });
    try numbers.append(tera.context.Value{ .number = 4 });
    try numbers.append(tera.context.Value{ .number = 1 });
    try numbers.append(tera.context.Value{ .number = 5 });

    try ctx.set("numbers", tera.context.Value{ .array = numbers });

    const result = try engine.render("filters", ctx);
    defer allocator.free(result);

    std.debug.print("{s}\n\n", .{result});
}

/// Example 5: Template inheritance
fn example5_inheritance(engine: *tera.Tera, allocator: std.mem.Allocator) !void {
    std.debug.print("5. Template Inheritance\n", .{});
    std.debug.print("-----------------------\n", .{});

    // Base template
    const base_template =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>{% block title %}Default Title{% endblock %}</title>
        \\</head>
        \\<body>
        \\    <header>
        \\        <h1>{% block header %}Welcome{% endblock %}</h1>
        \\    </header>
        \\    <main>
        \\        {% block content %}
        \\        <p>Default content</p>
        \\        {% endblock %}
        \\    </main>
        \\    <footer>
        \\        <p>&copy; 2024 Zig Templates</p>
        \\    </footer>
        \\</body>
        \\</html>
    ;

    // Child template
    const child_template =
        \\{% extends "base.html" %}
        \\
        \\{% block title %}{{ page_title }}{% endblock %}
        \\
        \\{% block header %}{{ page_title }}{% endblock %}
        \\
        \\{% block content %}
        \\<div class="article">
        \\    <h2>{{ article.title }}</h2>
        \\    <p class="meta">By {{ article.author }} on {{ article.date }}</p>
        \\    <div class="content">
        \\        {{ article.content }}
        \\    </div>
        \\</div>
        \\{% endblock %}
    ;

    try engine.addTemplate("base.html", base_template);
    try engine.addTemplate("article.html", child_template);

    var ctx = tera.context.Context.init(allocator);
    defer ctx.deinit();

    try ctx.set("page_title", tera.context.Value{ .string = "My Blog Article" });

    var article = tera.context.Context.init(allocator);
    defer article.deinit();
    try article.set("title", tera.context.Value{ .string = "Getting Started with Zig" });
    try article.set("author", tera.context.Value{ .string = "Jane Developer" });
    try article.set("date", tera.context.Value{ .string = "2024-01-15" });
    try article.set("content", tera.context.Value{ .string = "Zig is a systems programming language that focuses on safety, performance, and simplicity..." });

    try ctx.set("article", tera.context.Value{ .object = article });

    const result = try engine.render("article.html", ctx);
    defer allocator.free(result);

    std.debug.print("{s}\n\n", .{result});
}

/// Example 6: Complex data structures
fn example6_complex_data(engine: *tera.Tera, allocator: std.mem.Allocator) !void {
    std.debug.print("6. Complex Data Structures\n", .{});
    std.debug.print("--------------------------\n", .{});

    const template_content =
        \\<h2>Company: {{ company.name }}</h2>
        \\<p>Founded: {{ company.founded }}</p>
        \\<p>Employees: {{ company.employees | length }}</p>
        \\
        \\<h3>Departments</h3>
        \\{% for dept in company.departments %}
        \\<div class="department">
        \\    <h4>{{ dept.name }}</h4>
        \\    <p>Manager: {{ dept.manager.name }} ({{ dept.manager.email }})</p>
        \\    <p>Employees: {{ dept.employees | length }}</p>
        \\    <ul>
        \\    {% for emp in dept.employees %}
        \\        <li>{{ emp.name }} - {{ emp.position }}</li>
        \\    {% endfor %}
        \\    </ul>
        \\</div>
        \\{% endfor %}
    ;

    try engine.addTemplate("company", template_content);

    var ctx = tera.context.Context.init(allocator);
    defer ctx.deinit();

    // Create complex company structure
    var company = tera.context.Context.init(allocator);
    defer company.deinit();
    try company.set("name", tera.context.Value{ .string = "TechCorp Inc." });
    try company.set("founded", tera.context.Value{ .number = 2010 });

    // Create departments array
    var departments = std.ArrayList(tera.context.Value).init(allocator);
    defer departments.deinit();

    // Engineering department
    var eng_dept = tera.context.Context.init(allocator);
    defer eng_dept.deinit();
    try eng_dept.set("name", tera.context.Value{ .string = "Engineering" });

    var eng_manager = tera.context.Context.init(allocator);
    defer eng_manager.deinit();
    try eng_manager.set("name", tera.context.Value{ .string = "Alice Johnson" });
    try eng_manager.set("email", tera.context.Value{ .string = "alice@techcorp.com" });
    try eng_dept.set("manager", tera.context.Value{ .object = eng_manager });

    var eng_employees = std.ArrayList(tera.context.Value).init(allocator);
    defer eng_employees.deinit();

    var emp1 = tera.context.Context.init(allocator);
    defer emp1.deinit();
    try emp1.set("name", tera.context.Value{ .string = "Bob Smith" });
    try emp1.set("position", tera.context.Value{ .string = "Senior Developer" });
    try eng_employees.append(tera.context.Value{ .object = emp1 });

    var emp2 = tera.context.Context.init(allocator);
    defer emp2.deinit();
    try emp2.set("name", tera.context.Value{ .string = "Carol Davis" });
    try emp2.set("position", tera.context.Value{ .string = "DevOps Engineer" });
    try eng_employees.append(tera.context.Value{ .object = emp2 });

    try eng_dept.set("employees", tera.context.Value{ .array = eng_employees });
    try departments.append(tera.context.Value{ .object = eng_dept });

    try company.set("departments", tera.context.Value{ .array = departments });
    try ctx.set("company", tera.context.Value{ .object = company });

    const result = try engine.render("company", ctx);
    defer allocator.free(result);

    std.debug.print("{s}\n\n", .{result});
}

/// Example 7: Context from JSON
fn example7_custom_context(engine: *tera.Tera, allocator: std.mem.Allocator) !void {
    std.debug.print("7. Context from JSON\n", .{});
    std.debug.print("--------------------\n", .{});

    const template_content =
        \\<h2>{{ title }}</h2>
        \\<div class="config">
        \\    <p>Debug Mode: {{ debug }}</p>
        \\    <p>Version: {{ version }}</p>
        \\    <p>Features:</p>
        \\    <ul>
        \\    {% for feature in features %}
        \\        <li>{{ feature }}</li>
        \\    {% endfor %}
        \\    </ul>
        \\    <p>Database: {{ database.host }}:{{ database.port }}</p>
        \\</div>
    ;

    try engine.addTemplate("config", template_content);

    // Create context from JSON-like data
    const json_data =
        \\{
        \\  "title": "Application Configuration",
        \\  "debug": true,
        \\  "version": "1.2.3",
        \\  "features": ["authentication", "caching", "logging"],
        \\  "database": {
        \\    "host": "localhost",
        \\    "port": 5432,
        \\    "name": "myapp"
        \\  }
        \\}
    ;

    var ctx = try tera.context.Context.fromJson(allocator, json_data);
    defer ctx.deinit();

    const result = try engine.render("config", ctx);
    defer allocator.free(result);

    std.debug.print("{s}\n", .{result});
}
