const std = @import("std");
const net = std.net;
const http = std.http;

const API_TOKEN = "your-api-token-here"; // <<< REPLACE THIS!
const HOST = "localhost";
const PORT = 3000;
const PATH = "/api/v1/api/messages/send";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // The networking stack is now contained within the Client struct.
    // We only need to resolve the address and create a connection manager.

    // 1. Resolve Address and Prepare Connection
    // The `resolveIp` function takes the allocator as its first argument in recent Zig versions
    const address = try net.Address.resolveIp(allocator, HOST, PORT);
    var conn_mgr = net.tcp.ConnectionManager.init(allocator, address);

    // 2. Prepare the HTTP Client and Request
    // FIX: Initialize http.Client using struct literal instead of .init()
    var client = http.Client{
        .allocator = allocator,
        .connection_manager = &conn_mgr,
        .connection_timeout = null, // Use default or set a timeout
    };
    defer client.deinit();

    // Use a full URI for clarity and compliance with the client request method
    const uri = try std.Uri.parse(try std.fmt.allocPrint(allocator, "http://{s}:{d}{s}", .{ HOST, PORT, PATH }));
    defer allocator.free(uri.host); // Free the allocated URI string

    // The JSON payload to send
    const payload =
        \\{
        \\    "phone_number": "255689737459",
        \\    "message": "Hello from API Management endpoint!",
        \\    "sender_id": "137"
        \\}
    ;

    // 3. Set Headers
    // Authorization header value is prepared here
    const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{API_TOKEN});
    defer allocator.free(auth_header);

    const headers = [_]http.Header{
        .{ .name = "Authorization", .value = auth_header },
        .{ .name = "Content-Type", .value = "application/json" },
    };

    // 4. Send Request and Payload
    var request = try client.request(.POST, uri, .{
        .extra_headers = &headers,
    });
    defer request.deinit();

    // Send the payload
    try request.sendBodyComplete(payload);

    // 5. Read Response
    var buffer: [1024]u8 = undefined;
    var response = try request.receiveHead(&buffer);

    std.debug.print("Response Status: {s}\n", .{@tagName(response.head.status)});

    if (response.head.status == .ok) {
        std.debug.print("Response Headers:\n", .{});
        const reader = response.reader(.{});

        // Read the response body
        std.debug.print("\nResponse Body:\n", .{});

        const body_bytes = try reader.allocRemaining(allocator, .unlimited);
        defer allocator.free(body_bytes);
        std.debug.print("{s}", .{body_bytes});
        std.debug.print("\n", .{});
    } else {
        std.debug.print("HTTP Error: {s}\n", .{@tagName(response.head.status)});
    }
}
