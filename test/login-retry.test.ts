// `claude setup-token` that exits before printing a link cannot be finished from a phone. The old loop retried
// every 30 minutes forever and told the owner "a new link will follow" each time: L-0001…L-0086 over 54 hours,
// zero links, the whole fleet paused.
import { expect, test } from "bun:test";
import { loginBackoffMs, loginExitNotice } from "../src/accounts";

const base = { id: "L-0001", account: "claude-default", cli: "claude", host: "mac", code: 1, sent: false, output: "boom" };

test("first linkless exit tells the owner the local fix once", () => {
  const r = loginExitNotice({ ...base, fails: 1 });
  expect(r.notify).toBeDefined();
  expect(r.notify).toContain("claude /login");
  expect(r.notify).toMatch(/next in 30 min|约 30 分钟后/); // retryLogins waits loginBackoffMs(1) after the first failure
  expect(r.notify).not.toMatch(/new link will follow|稍后会再发新链接/);
  expect(r.journal).toContain("before printing a link");
  expect(r.journal).toContain("boom");
});

test("later linkless exits only journal, never notify", () => {
  for (const fails of [2, 3, 10, 86]) expect(loginExitNotice({ ...base, fails }).notify).toBeUndefined();
});

test("an exit after a link was sent still promises a new link", () => {
  expect(loginExitNotice({ ...base, sent: true, fails: 0 }).notify).toMatch(/new link will follow|稍后会再发新链接/);
});

test("success announces the fleet continues", () => {
  expect(loginExitNotice({ ...base, code: 0, fails: 0 }).notify).toMatch(/logged in|登录成功/);
});

test("tokens never reach the journal", () => {
  expect(loginExitNotice({ ...base, fails: 2, output: "x sk-ant-oat01-SECRET y" }).journal).not.toContain("SECRET");
});

test("backoff doubles from 30 minutes and caps at 6 hours", () => {
  const m = (n: number) => loginBackoffMs(n) / 60_000;
  expect([m(0), m(1), m(2), m(3), m(4), m(5), m(6), m(20)]).toEqual([30, 30, 60, 120, 240, 360, 360, 360]);
});
