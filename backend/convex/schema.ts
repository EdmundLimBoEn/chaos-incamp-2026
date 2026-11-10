import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
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
    updatedAt: v.number(),
    deletedAt: v.optional(v.number()),
  }).index("by_owner", ["owner"]).index("by_owner_client", ["owner", "clientId"]),
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
