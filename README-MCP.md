MCP and Supabase Agent Skills

1) MCP config
- File: .vscode/mcp.json was added to point VS Code MCP to the Supabase MCP endpoint.

2) Install Agent Skills
- Run the VS Code task "Install Supabase Agent Skills" or run in a terminal:

```bash
npx skills add supabase/agent-skills
```

3) Supabase setup in the dashboard
- Edit `Ministry_of_the_Fence_Dashboard_v2.html` and replace the placeholders:
  - `SUPABASE_URL` and `SUPABASE_KEY` with your project URL and anon key.

4) Run the task in VS Code
- Open the Command Palette (Ctrl+Shift+P) → "Tasks: Run Task" → "Install Supabase Agent Skills"

5) Notes
- Installing agent skills requires Node.js and network access.
- After installing skills, reload VS Code to enable any new assistant capabilities.
