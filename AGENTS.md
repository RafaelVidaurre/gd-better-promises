# Project guidance

- Do not preserve backward compatibility.
- Choose the simplest implementation that fully meets current requirements.
- Do not add speculative complexity.
- Prefer established, maintained libraries over custom implementations.
- Check dependency documentation and types before you replace dependency behavior.
- Prefer CLIs and MCP tools when they can complete the task.
- Make architectural decisions that can last.
- Keep components modular and concerns separate.
- Use ASD-STE100 Simplified Technical English in user messages.
- Use short sentences and active voice.
- Keep one topic in each paragraph.
- Do not add helper text unless it prevents an error or misunderstanding.
- Make each user message stand alone.

## Godot commands

- Use `ug` for every Godot command.
- Use the version in the repository `.ugrc` file.
- Do not run a Godot executable directly.

## Tests

- Use GUT for GDScript tests.
- Run the complete test suite with `tests/run.sh`.
- Do not create a custom GDScript test runner.

## Public repository

- Keep research and temporary records under `.crew/`.
- Do not commit `.crew/`.
- Exclude development dependencies and tests from published add-on archives.
