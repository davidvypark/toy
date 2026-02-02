import Link from 'next/link'

/**
 * Custom 404 page with TOY branding.
 * Shown when a video is not found or not published.
 */
export default function NotFound() {
  return (
    <main className="min-h-screen bg-toy-background flex flex-col items-center justify-center px-4">
      <div className="text-center max-w-md">
        {/* Icon */}
        <div className="mb-6">
          <svg
            className="mx-auto h-24 w-24 text-toy-text-secondary opacity-50"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="m15.75 10.5 4.72-4.72a.75.75 0 0 1 1.28.53v11.38a.75.75 0 0 1-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 0 0 2.25-2.25v-9a2.25 2.25 0 0 0-2.25-2.25h-9A2.25 2.25 0 0 0 2.25 7.5v9a2.25 2.25 0 0 0 2.25 2.25Z"
            />
          </svg>
        </div>

        {/* Message */}
        <h1 className="text-3xl font-serif text-toy-text mb-4">
          Video Not Found
        </h1>
        <p className="text-toy-text-secondary mb-8">
          This video may not exist or hasn't been published yet.
          Please check the link and try again.
        </p>

        {/* Action */}
        <Link
          href="https://sendtoycard.com"
          className="inline-flex items-center justify-center px-6 py-3 bg-toy-primary text-white rounded-full font-medium hover:bg-toy-primary-dark transition-colors"
        >
          Go to TOY
        </Link>
      </div>

      {/* Footer */}
      <footer className="absolute bottom-8 text-center">
        <p className="text-sm text-toy-text-secondary">
          <span className="text-toy-primary font-medium">TOY</span> - Thinking Of You
        </p>
      </footer>
    </main>
  )
}
