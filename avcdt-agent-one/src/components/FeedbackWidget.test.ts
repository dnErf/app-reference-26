import { render, fireEvent } from '@testing-library/vue'
import FeedbackWidget from './FeedbackWidget.vue'

describe('FeedbackWidget', () => {
  beforeEach(() => localStorage.clear())

  test('renders initial score and upvotes/downvotes', async () => {
    const { getByText, getByLabelText } = render(FeedbackWidget, { props: { itemId: 'article-1' } })

    expect(getByText(/Score:/)).toBeTruthy()

    const up = getByLabelText('Upvote')
    const down = getByLabelText('Downvote')

    await fireEvent.click(up)
    expect(getByText('Score:')).toBeTruthy()
    getByText('1')

    await fireEvent.click(down)
    getByText('0')
  })

  test('persists score in localStorage', async () => {
    const { getByLabelText } = render(FeedbackWidget, { props: { itemId: 'article-2' } })
    const up = getByLabelText('Upvote')
    await fireEvent.click(up)

    // new render should load persisted value
    const { getByText } = render(FeedbackWidget, { props: { itemId: 'article-2' } })
    getByText('1')
  })
})
