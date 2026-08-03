#!/usr/bin/env bash
# scaffold-test-file.sh - Create a test file with the correct template
# Usage: ./scaffold-test-file.sh <type> <output-path> [module-name]
# Types: unit | unit-tsx | browser | story | integration | e2e | api | check | bench | contract

set -euo pipefail

TYPE="${1:?Usage: scaffold-test-file.sh <type> <output-path> [module-name]}"
OUTPUT="${2:?Usage: scaffold-test-file.sh <type> <output-path> [module-name]}"
MODULE="${3:-Example}"

mkdir -p "$(dirname "$OUTPUT")"

case "$TYPE" in
  unit)
    cat > "$OUTPUT" << EOF
import { describe, it, expect } from 'vitest'
// import { ${MODULE} } from './${MODULE}'

describe('${MODULE}', () => {
  it('should work correctly', () => {
    // Arrange
    // Act
    // Assert
    expect(true).toBe(true)
  })

  it('handles edge cases', () => {
    // Test null, undefined, empty string, boundary values
  })
})
EOF
    ;;

  unit-tsx)
    cat > "$OUTPUT" << EOF
import { describe, it, expect } from 'vitest'
import { renderToString } from 'react-dom/server'
// import { ${MODULE} } from './${MODULE}'

describe('${MODULE}', () => {
  it('renders expected content', () => {
    const html = renderToString(
      // <${MODULE} />
      <div>placeholder</div>
    )
    expect(html).toContain('placeholder')
  })
})
EOF
    ;;

  browser)
    cat > "$OUTPUT" << EOF
import { describe, it, expect } from 'vitest'
import { render } from 'vitest-browser-react'
import { page } from 'vitest/browser'
// import { ${MODULE} } from './${MODULE}'

describe('${MODULE}', () => {
  it('renders correctly', async () => {
    // render(<${MODULE} />)
    // await expect.element(page.getByRole('button')).toBeVisible()
  })

  it('handles user interaction', async () => {
    // render(<${MODULE} />)
    // await page.getByRole('button').click()
    // await expect.element(page.getByText('Clicked')).toBeVisible()
  })
})
EOF
    ;;

  story)
    cat > "$OUTPUT" << EOF
import type { Meta, StoryObj } from '@storybook/react'
import { expect, userEvent, within } from '@storybook/test'
// import { ${MODULE} } from './${MODULE}'

const meta: Meta<typeof ${MODULE}> = {
  // component: ${MODULE},
  tags: ['autodocs'],
}
export default meta
type Story = StoryObj<typeof ${MODULE}>

export const Default: Story = {
  args: {},
}

export const WithInteraction: Story = {
  args: {},
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // await userEvent.click(canvas.getByRole('button'))
    // await expect(canvas.getByText('Result')).toBeVisible()
  },
}
EOF
    ;;

  integration)
    cat > "$OUTPUT" << EOF
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest'
// import { db } from '../../src/db'

describe('${MODULE} Integration', () => {
  beforeEach(async () => {
    // Clean test data - use beforeEach not afterEach for clean state
    // await db.delete(table)
  })

  it('performs the integration correctly', async () => {
    // Arrange: set up test data
    // Act: call the function under test
    // Assert: verify the result
  })
})
EOF
    ;;

  e2e)
    cat > "$OUTPUT" << EOF
import { test, expect } from '@playwright/test'
// import { ${MODULE}Page } from './pages/${MODULE}.page'

test.describe('${MODULE}', () => {
  test('completes the user flow', async ({ page }) => {
    // const pageObj = new ${MODULE}Page(page)
    // await pageObj.goto()
    // await expect(pageObj.heading).toBeVisible()
  })
})
EOF
    ;;

  api)
    cat > "$OUTPUT" << EOF
import { test, expect } from '@playwright/test'

test.describe('${MODULE} API', () => {
  test('GET returns expected response', async ({ request }) => {
    const response = await request.get('/api/${MODULE,,}')
    expect(response.status()).toBe(200)
    const body = await response.json()
    expect(body).toBeDefined()
  })
})
EOF
    ;;

  check)
    cat > "$OUTPUT" << EOF
import { ApiCheck, AssertionBuilder } from 'checkly/constructs'

const check = new ApiCheck('${MODULE,,}-health', {
  name: '${MODULE} Health Check',
  request: {
    method: 'GET',
    url: 'https://api.example.com/${MODULE,,}/health',
    assertions: [
      AssertionBuilder.statusCode().equals(200),
      AssertionBuilder.responseTime().lessThan(2000),
    ],
  },
  tags: ['api', 'health'],
})
EOF
    ;;

  bench)
    cat > "$OUTPUT" << EOF
import { bench, describe } from 'vitest'
// import { ${MODULE} } from './${MODULE}'

describe('${MODULE}', () => {
  bench('default case', () => {
    // ${MODULE}('input')
  })

  bench('large input', () => {
    // ${MODULE}('a'.repeat(1000))
  })
})
EOF
    ;;

  contract)
    cat > "$OUTPUT" << EOF
import { describe, it, expect } from 'vitest'
// import { createTestYoga } from '../helpers/yoga'

describe('Federation Contract', () => {
  // const yoga = createTestYoga()

  it('exposes valid SDL', async () => {
    // const res = await yoga.fetch(...)
    // expect(result.data._service.sdl).toContain('type ${MODULE}')
    // expect(result.data._service.sdl).toContain('@key')
  })

  it('resolves _entities', async () => {
    // Assert entity resolution works for federation
  })
})
EOF
    ;;

  *)
    echo "Unknown type: $TYPE"
    echo "Types: unit | unit-tsx | browser | story | integration | e2e | api | check | bench | contract"
    exit 1
    ;;
esac

echo "✅ Created $TYPE test file at $OUTPUT"
