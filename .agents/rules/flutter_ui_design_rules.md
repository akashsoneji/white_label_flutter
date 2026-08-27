# Antigravity Flutter UI Design Rules

1. **Aesthetics & Polish**:
   - Provide premium, high-contrast, modern UI designs with smooth curves and micro-animations.
   - Use themed tokens rather than raw hex values.
2. **Responsive Resilience**:
   - Build all screens to be adaptive across compact, medium, and wide screen sizes.
   - Avoid `RenderFlex` overflows by using `Expanded`/`Flexible` and `SingleChildScrollView` for scrollable forms.
3. **Performance Optimization**:
   - Prefer small `StatelessWidget` compositions with `const` constructors over private helper build functions.
   - Lazy load list views using `ListView.builder` or `CustomScrollView` + `SliverList`.
