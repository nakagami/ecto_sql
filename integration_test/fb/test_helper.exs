Logger.configure(level: :debug)

# Configure Ecto for support and tests
Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :async_integration_tests, true)
Application.put_env(:ecto_sql, :lock_for_update, "FOR UPDATE")

Code.require_file "../support/repo.exs", __DIR__

# Configure FB connection
Application.put_env(:ecto_sql, :fb_test_url,
  "ecto://" <> (System.get_env("FB_URL") || "sysdba:masterkey@localhost")
)

# Pool repo for async, safe tests
alias Ecto.Integration.TestRepo

Application.put_env(:ecto_sql, TestRepo,
  url: Application.get_env(:ecto_sql, :fb_test_url) <> "/ecto_test",
  pool: Ecto.Adapters.SQL.Sandbox)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto_sql, adapter: Ecto.Adapters.Firebird

  def uuid do
    Ecto.UUID
  end
end

# Pool repo for non-async tests
alias Ecto.Integration.PoolRepo

Application.put_env(:ecto_sql, PoolRepo,
  adapter: Ecto.Adapters.Firebird,
  url: Application.get_env(:ecto_sql, :fb_test_url) <> "/ecto_test",
  pool_size: 10)

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

{:ok, _} = Ecto.Adapters.Firebird.ensure_all_started(TestRepo.config(), :temporary)

#:ok = Ecto.Adapters.Firebird.storage_up(TestRepo.config)

{:ok, _pid} = TestRepo.start_link()
{:ok, _pid} = PoolRepo.start_link()

excludes = [
  :array_type,
  :read_after_writes,
  :create_index_if_not_exists,
  :aggregate_filters,
  :transaction_isolation,
  :with_conflict_target,
  :map_boolean_in_expression
]

ExUnit.configure(exclude: excludes)

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: :debug)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)

ExUnit.start()
