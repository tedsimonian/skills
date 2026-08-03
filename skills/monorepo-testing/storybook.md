# Storybook Reference

Storybook is for **shared UI component libraries only** (e.g., `@repo/ui`, `@repo/design-system`). App-specific components use Vitest Browser Mode instead.

## When to Use / Not Use

**Use Storybook for:** Shared UI component libraries, visual documentation, interaction tests via play functions, a11y audits via addon-a11y, visual regression via Chromatic.

**Do NOT use Storybook for:** App-specific components (pages, layouts with data fetching) → Vitest Browser Mode. Business logic / API calls → Vitest Node. E2E user flows → Playwright. Components requiring full app context (routers, auth, complex state trees).

## File Structure

```
packages/ui/
├── src/
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.stories.tsx     # Story + interaction test
│   │   └── index.ts
│   ├── Dialog/
│   │   ├── Dialog.tsx
│   │   ├── Dialog.stories.tsx
│   │   └── index.ts
│   └── index.ts
├── .storybook/
│   ├── main.ts
│   ├── preview.ts
│   └── vitest.setup.ts
├── vitest.config.ts
└── package.json
```

## Configuration

**.storybook/main.ts:**
```typescript
import type { StorybookConfig } from '@storybook/react-vite'

const config: StorybookConfig = {
  framework: '@storybook/react-vite',
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: ['@storybook/addon-essentials', '@storybook/addon-a11y', '@storybook/addon-vitest'],
}
export default config
```

**.storybook/preview.ts:**
```typescript
import type { Preview } from '@storybook/react'

const preview: Preview = {
  parameters: {
    controls: { matchers: { color: /(background|color)$/i, date: /Date$/i } },
    layout: 'centered',
  },
}
export default preview
```

**.storybook/vitest.setup.ts:**
```typescript
import { setProjectAnnotations } from '@storybook/react'
import * as projectAnnotations from './preview'

setProjectAnnotations([projectAnnotations])
```

**vitest.config.ts:**
```typescript
import { defineProject } from 'vitest/config'
import { storybookTest } from '@storybook/addon-vitest/vitest-plugin'
import { playwright } from '@vitest/browser-playwright'

export default defineProject({
  plugins: [storybookTest({ renderer: 'react' })],
  test: {
    name: 'ui/storybook',
    include: ['src/**/*.stories.tsx'],
    browser: {
      enabled: true,
      provider: playwright(),
      instances: [{ browser: 'chromium' }],
    },
    setupFiles: ['.storybook/vitest.setup.ts'],
  },
})
```

**⚠ Avoiding double-registration:** Do NOT import `storybookTest()` in per-app configs also discovered by root `projects` array. Only one config should contain the plugin.

## Play Function Decision Matrix

| Component Type | Play Function? | Reasoning |
|----------------|----------------|-----------|
| Buttons, toggles, switches | ✅ | Click handlers must fire |
| Form inputs, selects, date pickers | ✅ | User input handling critical |
| Modals, dialogs, drawers | ✅ | Open/close lifecycle, focus trap |
| Tabs, accordions, steppers | ✅ | State transitions |
| Tooltips, popovers | ✅ | Hover/focus triggers |
| Layout (grid, stack, columns) | ❌ | Visual only |
| Typography, badges, icons, avatars | ❌ | No interaction |

## Story Template with Interaction Test

```typescript
// Dialog.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { expect, userEvent, within } from '@storybook/test'
import { Dialog } from './Dialog'

const meta: Meta<typeof Dialog> = {
  component: Dialog,
  tags: ['autodocs'],
}
export default meta
type Story = StoryObj<typeof Dialog>

export const Default: Story = {
  args: { trigger: 'Open Dialog', title: 'Confirmation', content: 'Are you sure?' },
}

export const OpensAndCloses: Story = {
  args: Default.args,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(canvas.getByRole('button', { name: 'Open Dialog' }))
    await expect(canvas.getByRole('dialog')).toBeInTheDocument()
    await expect(canvas.getByText('Are you sure?')).toBeVisible()
    await userEvent.click(canvas.getByRole('button', { name: 'Close' }))
    await expect(canvas.queryByRole('dialog')).not.toBeInTheDocument()
  },
}

export const ClosesOnEscape: Story = {
  args: Default.args,
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(canvas.getByRole('button', { name: 'Open Dialog' }))
    await expect(canvas.getByRole('dialog')).toBeInTheDocument()
    await userEvent.keyboard('{Escape}')
    await expect(canvas.queryByRole('dialog')).not.toBeInTheDocument()
  },
}
```

## Dependencies

```bash
pnpm add -D @storybook/react-vite @storybook/addon-vitest \
  @storybook/addon-essentials @storybook/addon-a11y \
  @storybook/test storybook
```
