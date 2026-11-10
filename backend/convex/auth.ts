import { Password } from "@convex-dev/auth/providers/Password";
import { convexAuth } from "@convex-dev/auth/server";
import { ConvexError } from "convex/values";

export const { auth, signIn, signOut, store, isAuthenticated } = convexAuth({
  providers: [Password({
    profile(params) {
      const username = typeof params.username === "string" ? params.username.trim().toLowerCase() : "";
      if (!/^[a-z0-9_]{3,30}$/.test(username)) {
        throw new ConvexError("Username must be 3–30 letters, numbers or underscores.");
      }
      return { email: `${username}@sstincky.local`, name: username };
    },
  })],
});
