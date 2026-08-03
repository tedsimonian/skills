#!/usr/bin/env bash
# scaffold-vitest-config.sh - Generate vitest.config.ts for common package types
# Usage: ./scaffold-vitest-config.sh <type> <path>
# Types: server-utils | ui-storybook | graphql-api | fullstack-app | cli | spa

set -euo pipefail

TYPE="${1:?Usage: scaffold-vitest-config.sh <type> <path>}"
TARGET="${2:?Usage: scaffold-vitest-config.sh <type> <path>}"
NAME=$(basename "$TARGET")

case "$TYPE" in
  server-utils)
    cat > "$TARGET/vitest.config.ts" << 'EOF'
import { createNodeConfig } from '@repo/vitest-config/base'
import { defineProject, mergeConfig } from 'vitest/config'

export default mergeConfig(
  createNodeConfig(),
  defineProject({
    test: {
      name: '__NAME__',
      include: ['src/**/*.test.ts', 'tests/**/*.integration.test.ts'],
      environment: 'node',
    },
  })
)
EOF
    sed -i "s/__NAME__/$NAME/g" "$TARGET/vitest.config.ts"
    mkdir -p "$TARGET/tests/integration" "$TARGET/tests/fixtures"
    ;;

  ui-storybook)
    cat > "$TARGET/vitest.config.ts" << 'EOF'
import { defineProject } from 'vitest/config'
import { storybookTest } from '@storybook/addon-vitest/vitest-plugin'
import { playwright } from '@vitest/browser-playwright'

export default defineProject({
  plugins: [storybookTest({ renderer: 'react' })],
  test: {
    name: '__NAME__/storybook',
    include: ['src/**/*.stories.tsx'],
    browser: {
      enabled: true,
      provider: playwright(),
      instances: [{ browser: 'chromium' }],
    },
    setupFiles: ['.storybook/vitest.setup.ts'],
  },
})
EOF
    sed -i "s/__NAME__/$NAME/g" "$TARGET/vitest.config.ts"
    mkdir -p "$TARGET/.storybook"

    cat > "$TARGET/.storybook/main.ts" << 'EOF'
import type { StorybookConfig } from '@storybook/react-vite'

const config: StorybookConfig = {
  framework: '@storybook/react-vite',
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: ['@storybook/addon-essentials', '@storybook/addon-a11y', '@storybook/addon-vitest'],
}
export default config
EOF

    cat > "$TARGET/.storybook/preview.ts" << 'EOF'
import type { Preview } from '@storybook/react'

const preview: Preview = {
  parameters: {
    controls: { matchers: { color: /(background|color)$/i, date: /Date$/i } },
    layout: 'centered',
  },
}
export default preview
EOF

    cat > "$TARGET/.storybook/vitest.setup.ts" << 'EOF'
import { setProjectAnnotations } from '@storybook/react'
import * as projectAnnotations from './preview'

setProjectAnnotations([projectAnnotations])
EOF
    ;;

  graphql-api)
    cat > "$TARGET/vitest.config.ts" << 'EOF'
import { defineConfig } from 'vitest/config'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    projects: [
      {
        test: {
          name: '__NAME__/unit',
          include: ['src/**/*.test.ts'],
          environment: 'node',
          globals: true,
          setupFiles: ['tests/setup.ts'],
        },
      },
      {
        test: {
          name: '__NAME__/integration',
          include: [
            'tests/integration/**/*.integration.test.ts',
            'tests/contracts/**/*.contract.ts',
          ],
          environment: 'node',
          globals: true,
          fileParallelism: false,
          testTimeout: 15_000,
          hookTimeout: 30_000,
          setupFiles: ['tests/setup.ts', 'tests/setup-db.ts'],
        },
      },
    ],
  },
})
EOF
    sed -i "s/__NAME__/$NAME/g" "$TARGET/vitest.config.ts"
    mkdir -p "$TARGET/tests/integration" "$TARGET/tests/contracts" "$TARGET/tests/fixtures" "$TARGET/tests/factories" "$TARGET/tests/helpers" "$TARGET/tests/generated"

    cat > "$TARGET/tests/setup.ts" << 'EOF'
import { afterEach, vi } from 'vitest'

afterEach(() => {
  vi.clearAllMocks()
  vi.restoreAllMocks()
})
EOF

    cat > "$TARGET/tests/setup-db.ts" << 'EOF'
import { beforeAll, afterAll } from 'vitest'
// import { db, migrateUp, migrateDown } from '../src/db'

beforeAll(async () => {
  // await migrateUp()
})

afterAll(async () => {
  // await migrateDown()
  // await db.$client.end()
})
EOF
    ;;

  fullstack-app)
    cat > "$TARGET/vitest.config.ts" << 'EOF'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { playwright } from '@vitest/browser-playwright'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    projects: [
      {
        test: {
          name: '__NAME__/unit',
          include: ['app/**/*.test.ts', 'app/**/*.test.tsx'],
          environment: 'node',
          globals: true,
        },
      },
      {
        extends: true,
        test: {
          name: '__NAME__/browser',
          include: ['app/**/*.browser.test.tsx'],
          globals: true,
          browser: {
            enabled: true,
            provider: playwright(),
            instances: [{ browser: 'chromium' }],
          },
        },
      },
      {
        test: {
          name: '__NAME__/integration',
          include: ['tests/integration/**/*.integration.test.ts'],
          environment: 'node',
          globals: true,
          fileParallelism: false,
          testTimeout: 15_000,
        },
      },
    ],
  },
})
EOF
    sed -i "s/__NAME__/$NAME/g" "$TARGET/vitest.config.ts"
    mkdir -p "$TARGET/tests/e2e/pages" "$TARGET/tests/integration" "$TARGET/tests/fixtures" "$TARGET/tests/mocks"
    ;;

  cli)
    cat > "$TARGET/vitest.config.ts" << 'EOF'
import { createNodeConfig } from '@repo/vitest-config/base'
import { defineProject, mergeConfig } from 'vitest/config'

export default mergeConfig(
  createNodeConfig(),
  defineProject({
    test: {
      name: '__NAME__',
      include: ['src/**/*.test.ts', 'tests/**/*.integration.test.ts'],
      environment: 'node',
    },
  })
)
EOF
    sed -i "s/__NAME__/$NAME/g" "$TARGET/vitest.config.ts"
    mkdir -p "$TARGET/tests/integration" "$TARGET/tests/fixtures/config-files"
    ;;

  spa)
    cat > "$TARGET/vitest.config.ts" << 'EOF'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { playwright } from '@vitest/browser-playwright'
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    projects: [
      {
        test: {
          name: '__NAME__/unit',
          include: ['src/**/*.test.ts', 'src/**/*.test.tsx'],
          environment: 'node',
          globals: true,
        },
      },
      {
        extends: true,
        test: {
          name: '__NAME__/browser',
          include: ['src/**/*.browser.test.tsx'],
          globals: true,
          browser: {
            enabled: true,
            provider: playwright(),
            instances: [{ browser: 'chromium' }],
          },
        },
      },
    ],
  },
})
EOF
    sed -i "s/__NAME__/$NAME/g" "$TARGET/vitest.config.ts"
    mkdir -p "$TARGET/tests/e2e/pages"
    ;;

  *)
    echo "Unknown type: $TYPE"
    echo "Types: server-utils | ui-storybook | graphql-api | fullstack-app | cli | spa"
    exit 1
    ;;
esac

echo "✅ Created vitest.config.ts for $TYPE at $TARGET"
