defmodule Changelog.Post do
  use Changelog.Data

  alias Changelog.{Person, PostTopic, Regexp}

  schema "posts" do
    field :title, :string

    field :slug, :string
    field :guid, :string

    field :tldr, :string
    field :body, :string

    field :published, :boolean, default: false
    field :published_at, DateTime

    belongs_to :author, Person
    has_many :post_topics, PostTopic, on_delete: :delete_all
    has_many :topics, through: [:post_topics, :topic]

    timestamps()
  end

  def admin_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(title slug author_id published published_at body tldr))
    |> validate_required([:title, :slug, :author_id])
    |> validate_format(:slug, Regexp.slug, message: Regexp.slug_message)
    |> unique_constraint(:slug)
    |> validate_published_has_published_at
    |> cast_assoc(:post_topics)
  end

  def published(query \\ __MODULE__) do
    from p in query,
      where: p.published == true,
      where: p.published_at <= ^Timex.now
  end

  def scheduled(query \\ __MODULE__) do
    from p in query,
      where: p.published == true,
      where: p.published_at > ^Timex.now
  end

  def unpublished(query \\ __MODULE__) do
    from p in query, where: p.published == false
  end

  def newest_first(query \\ __MODULE__, field \\ :published_at) do
    from e in query, order_by: [desc: ^field]
  end

  def newest_last(query \\ __MODULE__, field \\ :published_at) do
    from e in query, order_by: [asc: ^field]
  end

  def limit(query, count) do
    from e in query, limit: ^count
  end

  def search(query, search_term) do
    from e in query,
      where: fragment("search_vector @@ plainto_tsquery('english', ?)", ^search_term)
  end

  def is_public(post, as_of \\ Timex.now) do
    post.published && post.published_at <= as_of
  end

  def preload_all(post) do
    post
    |> preload_author
    |> preload_topics
  end

  def preload_author(post) do
    post
    |> Repo.preload(:author)
  end

  def preload_topics(post) do
    post
    |> Repo.preload(post_topics: {PostTopic.by_position, :topic})
    |> Repo.preload(:topics)
  end

  defp validate_published_has_published_at(changeset) do
    published = get_field(changeset, :published)
    published_at = get_field(changeset, :published_at)

    if published && is_nil(published_at) do
      add_error(changeset, :published_at, "can't be blank when published")
    else
      changeset
    end
  end
end
