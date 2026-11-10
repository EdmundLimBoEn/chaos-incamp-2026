import { defineSchema, defineTable } from "convex/server";
import { authTables } from "@convex-dev/auth/server";
import { v } from "convex/values";

export default defineSchema({
  ...authTables,
  events: defineTable({
    owner: v.string(),
    clientId: v.string(),
    title: v.string(),
    start: v.number(),
    end: v.number(),
    isAllDay: v.boolean(),
    location: v.string(),
    notes: v.string(),
    color: v.string(),
    reminderMinutes: v.optional(v.number()),
    people: v.optional(v.array(v.string())),
    tags: v.optional(v.array(v.string())),
    hostName: v.optional(v.string()),
    updatedAt: v.number(),
    deletedAt: v.optional(v.number()),
  }).index("by_owner", ["owner"]).index("by_owner_client", ["owner", "clientId"]),
  hosts: defineTable({
    owner: v.string(),
    displayName: v.string(),
    bio: v.string(),
    updatedAt: v.number(),
  }).index("by_owner", ["owner"]),
  publicListings: defineTable({
    owner: v.string(),
    hostId: v.id("hosts"),
    title: v.string(),
    description: v.string(),
    tags: v.array(v.string()),
    start: v.number(),
    end: v.number(),
    location: v.string(),
    published: v.boolean(),
    searchText: v.string(),
    updatedAt: v.number(),
  }).index("by_public_start", ["published", "start"])
    .index("by_owner", ["owner"])
    .searchIndex("search_public", { searchField: "searchText", filterFields: ["published", "hostId"] }),
  agentGrants: defineTable({
    owner: v.string(),
    agentSubject: v.string(),
    canWrite: v.boolean(),
    expiresAt: v.number(),
    revokedAt: v.optional(v.number()),
  }).index("by_owner_agent", ["owner", "agentSubject"]),
  audit: defineTable({
    owner: v.string(),
    actor: v.string(),
    action: v.string(),
    clientId: v.optional(v.string()),
    at: v.number(),
  }).index("by_owner", ["owner"]),
});
