# MDX Component Documentation Standard

## Scope

**Applies ONLY to: `docs/pages/components/*.mdx`**

Do NOT apply to `/content/`, other `/docs/pages/` files, or READMEs.

---

## Quick Reference

### Section Order (Mandatory)

```
1. Frontmatter (title, description)
2. # Title (H1)
3. Intro paragraph (no heading)
4. :::tip[Interactive Playground]
5. ## Preview (1 iframe)
6. ## When to Use (bullets)
7. ## Variants/Features (0-2 iframes, optional)
8. ## Comparison (table, when applicable)
9. ## Best Practices (bullets)
10. ## Accessibility (bullets)
11. ## Usage (code, no imports)
```

### Target Metrics

| Metric                | Target       | Maximum   |
| --------------------- | ------------ | --------- |
| File length           | 60-100 lines | 400 lines |
| Variant iframes       | 1-2          | 2         |
| Best practice bullets | 4-6          | 6         |
| Use case bullets      | 3-6          | 6         |

---

## Boundaries

### Always Do

- Follow the exact section order
- Include `:::tip[Interactive Playground]` with Storybook link
- Include Preview iframe with default story
- Use bullet format for When to Use, Best Practices, Accessibility
- Add Comparison table when a related component exists
- Use `tsx` code blocks in Usage section
- Keep files under 100 lines

### Ask First

- Adding more than 2 variant iframes
- Exceeding 100 lines
- Deviating from section order
- Adding new section types

### Never Do

- Include Props tables (removed from all component docs)
- Add import statements in Usage examples
- Use screenshots instead of Storybook iframes
- Skip the Accessibility section
- Use verbose prose when bullets suffice

---

## Template

````mdx
---
title: Component Name
description: One-line description (max 160 chars)
---

# Component Name

Brief paragraph explaining what the component does and key capabilities.

:::tip[Interactive Playground]
Try the interactive demo in [Storybook](/storybook/?path=/docs/category-componentname--docs).
:::

## Preview

<iframe
  src="/storybook/iframe.html?id=category-componentname--default&viewMode=story"
  width="100%"
  height="300"
></iframe>

## When to Use

- **use case**: brief explanation
- **another case**: brief explanation

## Variants

Optional intro text:

<iframe
  src="/storybook/iframe.html?id=category-componentname--variant&viewMode=story"
  width="100%"
  height="300"
></iframe>

## Comparison

| Aspect       | ComponentA | ComponentB |
| ------------ | ---------- | ---------- |
| **Purpose**  | X          | Y          |
| **Use case** | A          | B          |

## Best Practices

- start with verb (use, keep, avoid)
- actionable and specific
- lowercase throughout

## Accessibility

- semantic markup details
- keyboard navigation
- screen reader support

## Usage

```tsx
{
  /* Basic */
}
<ComponentName prop="value" />;

{
  /* With options */
}
<ComponentName prop="value" variant="option" />;
```
````

````

---

## Component Pairs (Require Comparison)

When editing these components, ensure both files have matching Comparison sections:

| Component A | Component B |
|-------------|-------------|
| Banner | Callout |
| Card | LinkCard |
| CodeBlock | DiffBlock |
| Diagram | Mermaid |
| Drawer | Modal |
| Figure | Image |
| HeroSimple | HeroSplit |
| Highlight | Mark |
| LottieMultiPlayer | DotLottiePlayer |
| Popover | Tooltip |
| Roadmap | Timeline |
| Spoiler | Toggle, Accordion |
| StackBlitz | CodeSandbox, CodePen |
| StatusBadge | VersionBadge |
| Stepper | Steps |
| Video | YouTube, Vimeo |

---

## Section Details

### Frontmatter
- `title`: Component name in Title Case
- `description`: SEO description, max 160 characters

### Intro Paragraph
- 1-2 sentences, no heading
- Explain what component does and key capabilities

### Interactive Playground Tip
```mdx
:::tip[Interactive Playground]
Try the interactive demo in [Storybook](/storybook/?path=/docs/category-componentname--docs).
:::
````

### Preview

- Single iframe with default story
- Always `width="100%"`
- Height: 200-400px based on content

### When to Use

- Bold label followed by colon and lowercase explanation
- Focus on scenarios and use cases, not features
- 3-6 bullets

### Variants/Features (Optional)

- Brief intro before each iframe
- Maximum 2 iframes total
- Only show meaningfully different variants

### Comparison

- Use when related component exists (see pairs above)
- 2-4 row table comparing key aspects
- Bold the Aspect column labels

### Best Practices

- Start each bullet with a verb
- Actionable guidance only
- 4-6 bullets

### Accessibility

- Semantic HTML/ARIA usage
- Keyboard navigation
- Screen reader announcements
- Color contrast considerations
- 3-5 bullets

### Usage

- `tsx` code block
- NO import statements
- 2-3 examples with comment labels
- Show common patterns

---

## Validation Checklist

Before marking complete:

- [ ] Section order matches template exactly
- [ ] Has `:::tip[Interactive Playground]`
- [ ] Has Preview with single iframe
- [ ] Has When to Use with 3-6 bullets
- [ ] Has Comparison (if paired component exists)
- [ ] Has Best Practices with 4-6 bullets
- [ ] Has Accessibility with 3-5 bullets
- [ ] Has Usage with no imports
- [ ] No Props table anywhere
- [ ] File is under 100 lines
- [ ] Maximum 2 variant iframes