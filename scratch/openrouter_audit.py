import os
import json
import urllib.request

def main():
    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        print("Error: OPENROUTER_API_KEY is not set.")
        return

    # Load source files
    files = ["build.zig", "src/main.zig", "src/graph.zig", "src/export.zig"]
    code_bundle = {}
    for f in files:
        if os.path.exists(f):
            with open(f, "r") as file_handle:
                code_bundle[f] = file_handle.read()

    # Prepare prompt
    prompt = f"""You are an expert systems programmer and Zig compiler authority. You are auditing a zero-dependency capability graph CLI tool named `ag` built using Zig 0.16.0.
The CLI persists graph state to `.ag/graph.json` and exports `.vaked` files.

Please review the source files below. Search for:
1. Memory leaks or double-frees (e.g., incorrect ArrayList allocations/frees).
2. JSON parsing edge cases (e.g., missing keys, invalid types, malformed format handling).
3. Logic bugs in subcommand execution (init, declare, link, status, push, seal).
4. Alignment with Zig 0.16.0 language features and library interfaces.
5. Missing check conditions (e.g., validation rules).

Provide a detailed review report. For any identified issue, supply the file, line, brief description, and concrete Zig code fix.

Code bundle:
"""
    for f, code in code_bundle.items():
        prompt += f"\n--- {f} ---\n{code}\n"

    # Send request to OpenRouter
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/vaked-swarm/antigravity", # Required by OpenRouter
        "X-Title": "Anti-Gravity CLI Auditor"
    }
    
    # We use deepseek/deepseek-chat
    data = {
        "model": "deepseek/deepseek-chat",
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.1
    }
    
    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    
    print("Calling OpenRouter API...")
    try:
        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            content = res_data["choices"][0]["message"]["content"]
            os.makedirs("scratch", exist_ok=True)
            with open("scratch/openrouter_report.md", "w") as out_f:
                out_f.write(content)
            print("Audit report written to scratch/openrouter_report.md")
    except Exception as e:
        print("API Call failed:", e)

if __name__ == "__main__":
    main()
