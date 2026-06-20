import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	createBashTool,
	createEditTool,
	createFindTool,
	createGrepTool,
	createLsTool,
	createReadTool,
	createWriteTool,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { homedir } from "node:os";

type BuiltInToolName = "read" | "bash" | "edit" | "write" | "find" | "grep" | "ls";

function shortenPath(path: string): string {
	const home = homedir();
	return path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

function createBuiltInTools(cwd: string) {
	return {
		read: createReadTool(cwd),
		bash: createBashTool(cwd),
		edit: createEditTool(cwd),
		write: createWriteTool(cwd),
		find: createFindTool(cwd),
		grep: createGrepTool(cwd),
		ls: createLsTool(cwd),
	};
}

const toolCache = new Map<string, ReturnType<typeof createBuiltInTools>>();

function getBuiltInTools(cwd: string) {
	let tools = toolCache.get(cwd);
	if (!tools) {
		tools = createBuiltInTools(cwd);
		toolCache.set(cwd, tools);
	}
	return tools;
}

function formatToolCall(name: BuiltInToolName, args: Record<string, any>, theme: any): string {
	const title = (text: string) => theme.fg("toolTitle", theme.bold(text));
	const path = (value: string | undefined, fallback = ".") => theme.fg("accent", shortenPath(value || fallback));
	const dim = (value: string) => theme.fg("dim", value);

	switch (name) {
		case "bash":
			return `${title("$")} ${theme.fg("accent", args.command || "...")}${args.timeout ? dim(` (${args.timeout}s)`) : ""}`;
		case "read": {
			let suffix = "";
			if (args.offset !== undefined || args.limit !== undefined) {
				const start = args.offset ?? 1;
				const end = args.limit !== undefined ? start + args.limit - 1 : "";
				suffix = theme.fg("warning", `:${start}${end ? `-${end}` : ""}`);
			}
			return `${title("read")} ${path(args.path, "")}${suffix}`;
		}
		case "write": {
			const lines = typeof args.content === "string" ? args.content.split("\n").length : 0;
			return `${title("write")} ${path(args.path, "")}${lines ? dim(` (${lines} lines)`) : ""}`;
		}
		case "edit":
			return `${title("edit")} ${path(args.path, "")}`;
		case "find":
			return `${title("find")} ${theme.fg("accent", args.pattern || "*")} ${dim(`in ${shortenPath(args.path || ".")}`)}`;
		case "grep":
			return `${title("grep")} ${theme.fg("accent", `/${args.pattern || ""}/`)} ${dim(`in ${shortenPath(args.path || ".")}`)}`;
		case "ls":
			return `${title("ls")} ${path(args.path)}`;
	}
}

function renderExpandedResult(result: any, theme: any): Text {
	const textContent = result.content?.find((item: any) => item.type === "text");
	if (!textContent?.text) return new Text("", 0, 0);

	const output = String(textContent.text)
		.replace(/\s+$/u, "")
		.split("\n")
		.map((line) => theme.fg("toolOutput", line))
		.join("\n");

	return new Text(output ? `\n${output}` : "", 0, 0);
}

export default function (pi: ExtensionAPI) {
	for (const name of ["read", "bash", "edit", "write", "find", "grep", "ls"] as BuiltInToolName[]) {
		const original = getBuiltInTools(process.cwd())[name] as any;

		pi.registerTool({
			name,
			label: name,
			description: original.description,
			parameters: original.parameters,

			async execute(toolCallId, params, signal, onUpdate, ctx) {
				const tool = (getBuiltInTools(ctx.cwd) as any)[name];
				return tool.execute(toolCallId, params, signal, onUpdate);
			},

			renderCall(args, theme, _context) {
				return new Text(formatToolCall(name, args, theme), 0, 0);
			},

			renderResult(result, { expanded }, theme, _context) {
				if (!expanded) return new Text("", 0, 0);
				return renderExpandedResult(result, theme);
			},
		});
	}
}
