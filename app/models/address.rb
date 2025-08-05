class Address < ApplicationRecord
  after_create_commit :generate_summary_and_embedding

  def generate_summary_and_embedding
    SummaryEmbeddingJob.perform_later(self.id, self.address_hash)
  end
end
