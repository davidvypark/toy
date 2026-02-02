export default function Home() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-toy-background px-6">
      <main className="flex flex-col items-center text-center">
        <h1 className="text-5xl font-normal text-toy-text mb-4">
          TOY
        </h1>
        <p className="text-xl text-toy-text-secondary mb-8">
          Video greeting cards that bring people together
        </p>
        <p className="text-sm text-toy-text-secondary max-w-md">
          Create heartfelt group video messages for birthdays, celebrations, and special moments.
          Coming soon to the App Store.
        </p>
      </main>
    </div>
  );
}
