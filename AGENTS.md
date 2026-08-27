# AI Assistant Guidelines for Flutter Development

## Core Principles
1. **Responsive & Adaptive UI**:
   - Follow Flutter official layout rules (`constraints down, sizes up, parent sets position`).
   - Use `LayoutBuilder`, `MediaQuery.sizeOf(context)`, and `Flexible`/`Expanded` to prevent `RenderFlex` overflows.
2. **Design & Theming**:
   - Strictly avoid hardcoded color literals (`Color(0xFF...)`). Always consume `Theme.of(context).colorScheme` or `ThemeExtension`.
   - Maintain high visual polish (glassmorphism, subtle card borders, consistent rounded corners, smooth micro-interactions).
3. **Performance**:
   - Use `const` constructors everywhere applicable.
   - Use `ListView.builder` / `SliverList` for long lists.
   - Isolate frequent repaints with `RepaintBoundary`.
4. **Skills Location**:
   - Detailed task-oriented skills are located in `.agents/skills/` and `.claude/skills/`.
