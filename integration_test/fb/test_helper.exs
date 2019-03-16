Logger.configure(level: :info)

# Configure Ecto for support and tests
Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :async_integration_tests, true)
Application.put_env(:ecto_sql, :lock_for_update, "FOR UPDATE")

# Configure PG connection
Application.put_env(:ecto_sql, :pg_test_url,
  "ecto://" <> (System.get_env("FB_URL") || "sysdba:masterkey@localhost")
)

Code.require_file "../support/repo.exs", __DIR__

# Pool repo for async, safe tests
alias Ecto.Integration.TestRepo

Application.put_env(:ecto_sql, TestRepo,
  url: Application.get_env(:ecto_sql, :pg_test_url) <> "/ecto_test",
  pool: Ecto.Adapters.SQL.Sandbox)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto_sql, adapter: Ecto.Adapters.Firebird

  def create_prefix(prefix) do
    ""
  end

  def drop_prefix(prefix) do
    ""
  end

  def uuid do
    Ecto.UUID
  end
end

# Pool repo for non-async tests
alias Ecto.Integration.PoolRepo

Application.put_env(:ecto_sql, PoolRepo,
  url: Application.get_env(:ecto_sql, :pg_test_url) <> "/tmp/ecto_test.fdb",
  pool_size: 10,
  max_restarts: 20,
  max_seconds: 10)

defmodule Ecto.Integration.PoolRepo do
  use Ecto.Integration.Repo, otp_app: :ecto_sql, adapter: Ecto.Adapters.Firebird
end

# Load support files
ecto = Mix.Project.deps_paths[:ecto]
Code.require_file "#{ecto}/integration_test/support/schemas.exs", __DIR__
Code.require_file "../support/migration.exs", __DIR__

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)
  end
end

{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(TestRepo.config(), :temporary)

# Load up the repository, start it, and run migrations
_   = Ecto.Adapters.Postgres.storage_down(TestRepo.config)
:ok = Ecto.Adapters.Postgres.storage_up(TestRepo.config)

{:ok, _pid} = TestRepo.start_link()
{:ok, _pid} = PoolRepo.start_link()

excludes = [:add_column_if_not_exists, :no_error_on_conditional_column_migration]
ExUnit.configure(exclude: excludes)

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)

ExUnit.start()
