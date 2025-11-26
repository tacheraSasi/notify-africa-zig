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

    const address = try net.Address.resolveIp(HOST, PORT);
    const conn = try net.tcpConnectToAddress(address);
    defer conn.close();

    // 1. Prepare the HTTP Client and Request
    var client = http.Client.init(.{ .allocator = allocator, .connection = conn });
    defer client.deinit();

    const request = try client.request(.{
        .method = .POST,
        .uri = PATH,
        .host = HOST,
        .port = PORT,
    });
    defer request.deinit();

    // The JSON payload to send
    const payload =
        \\{
        \\    "phone_number": "255689737459",
        \\    "message": "Hello from API Management endpoint!",
        \\    "sender_id": "137"
        \\}
    ;

    // 2. Set Headers
    // Authorization header
    try request.setHeader("Authorization", try std.fmt.allocPrint(allocator, "Bearer {s}", .{API_TOKEN}));
    // Content-Type header
    try request.setHeader("Content-Type", "application/json");

    // 3. Send Request and Payload
    try request.send();
    const writer = request.transfer.writer();
    try writer.writeAll(payload);
    try request.finish();

    // 4. Read Response
    const response = try request.response();

    std.debug.print("Response Status: {s}\n", .{@tagName(response.status)});

    if (response.status == .ok) {
        std.debug.print("Response Headers:\n", .{});
        while (try response.getHeaders().next()) |header| {
            std.debug.print("- {s}: {s}\n", .{ header.name, header.value });
        }

        // Read the response body
        std.debug.print("\nResponse Body:\n", .{});
        var buffer: [1024]u8 = undefined;
        const reader = response.transfer.reader();
        while (reader.read(buffer[0..])) |len| {
            std.debug.print("{s}", .{buffer[0..len]});
        }
        std.debug.print("\n", .{});
    } else {
        std.debug.print("HTTP Error: {s}\n", .{@tagName(response.status)});
    }
}
