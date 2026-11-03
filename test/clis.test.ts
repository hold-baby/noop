// CLI choice: a planner-pinned CLI must not strand a task on hosts that lack it.
import { expect, test } from "bun:test";
const { allowedClis } = await import("../src/core");

test("pinned cli goes first and keeps the other as fallback", () => {
  expect(allowedClis({ agent: "dispatcher", cli: "codex" }, {} as any)).toEqual(["codex", "claude"]);
  expect(allowedClis({ agent: "lead", cli: "claude" }, {} as any)).toEqual(["claude", "codex"]);
});

test("auto uses the per-agent list, then the default", () => {
  expect(allowedClis({ agent: "reviewer", cli: "auto" }, { clis: { agents: { reviewer: ["codex"] } } } as any)).toEqual(["codex"]);
  expect(allowedClis({ agent: "lead" }, {} as any)).toEqual(["claude", "codex"]);
});
