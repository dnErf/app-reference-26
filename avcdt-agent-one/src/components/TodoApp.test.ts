import { render, fireEvent } from '@testing-library/vue'
import TodoApp from './TodoApp.vue'

// Simple smoke and behavior tests
describe('TodoApp', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  test('renders and adds a todo', async () => {
    const { getByPlaceholderText, getByText } = render(TodoApp)

    const input = getByPlaceholderText('Add todo') as HTMLInputElement
    await fireEvent.update(input, 'Test item')
    await fireEvent.keyUp(input, { key: 'Enter' })

    expect(getByText('Test item')).toBeTruthy()
  })

  test('toggles and removes todo', async () => {
    const { getByPlaceholderText, getByText, queryByText } = render(TodoApp)

    const input = getByPlaceholderText('Add todo') as HTMLInputElement
    await fireEvent.update(input, 'To remove')
    await fireEvent.keyUp(input, { key: 'Enter' })

    const item = getByText('To remove')
    expect(item).toBeTruthy()

    const checkbox = item.parentElement!.querySelector('input[type="checkbox"]') as HTMLInputElement
    await fireEvent.click(checkbox)
    // after toggle, item should still be in document
    expect(getByText('To remove')).toBeTruthy()

    const removeBtn = getByText('Remove')
    await fireEvent.click(removeBtn)
    expect(queryByText('To remove')).toBeNull()
  })
})
