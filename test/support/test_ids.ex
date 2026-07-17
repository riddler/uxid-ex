defmodule UXID.TestSupport.Org do
  @moduledoc false
end

defmodule UXID.TestSupport.Contact do
  @moduledoc false
end

defmodule UXID.TestSupport.IDs do
  @moduledoc false
  use UXID.Registry,
    default_size: :medium,
    default_validate: true

  defid :org, prefix: "org", schema: UXID.TestSupport.Org, category: :account

  defid :contact,
    prefix: "contact",
    size: :large,
    schema: UXID.TestSupport.Contact,
    allow_uuid: false

  defid :lead, prefix: "lead"
  defid :in_ref, prefix: "in_ref", size: :small

  retired "usr"
end
