class VirtualTotalTestBase < ActiveRecord::Base
  self.abstract_class = true

  include VirtualFields
end

class Author < VirtualTotalTestBase
  has_many :books
  has_many :ordered_books,   -> { ordered },   :class_name => "Book"
  has_many :published_books, -> { published }, :class_name => "Book"
  has_many :wip_books,       -> { wip },       :class_name => "Book"
  has_and_belongs_to_many :co_books,           :class_name => "Book"
  has_many :bookmarks,                         :class_name => "Bookmark", :through => :books
  has_many :photos, :as => :imageable, :class_name => "Photo"
  has_one :current_photo, -> { all.merge(Photo.order(:id => :desc)) }, :as => :imageable, :class_name => "Photo"

  virtual_total :total_books, :books
  virtual_total :total_books_published, :published_books
  virtual_total :total_books_in_progress, :wip_books
  # same as total_books, but going through a relation with order
  virtual_total :total_ordered_books, :ordered_books
  # virtual total using through
  virtual_total :total_bookmarks, :bookmarks
  alias v_total_bookmarks total_bookmarks

  has_many :recently_published_books, -> { published.order(:created_on => :desc) },
           :class_name => "Book", :foreign_key => "author_id"

  virtual_total :total_recently_published_books, :recently_published_books
  virtual_average :average_recently_published_books_rating, :recently_published_books, :rating
  virtual_minimum :minimum_recently_published_books_rating, :recently_published_books, :rating
  virtual_maximum :maximum_recently_published_books_rating, :recently_published_books, :rating
  virtual_sum :sum_recently_published_books_rating, :recently_published_books, :rating
  virtual_delegate :description, :to => :current_photo, :prefix => true

  # This is here to provide a virtual_total of a virtual_has_many that depends upon an array of associations.
  # NOTE: this is tailored to the use case and is not an optimal solution
  def named_books
    # I didn't have the creativity needed to find a good ruby only check here
    books.select(&:name)
  end

  # virtual_has_many that depends upon a hash of a virtual column in another model.
  # NOTE: this is tailored to the use case and is not an optimal solution
  def books_with_authors
    books.select { |b| b.name && b.author_name }
  end

  virtual_has_many :named_books, :class_name => "Book", :uses => [:books]
  virtual_has_many :books_with_authors, :class_name => "Book", :uses => {:books => :author_name}
  virtual_total :total_named_books, :named_books
  alias v_total_named_books total_named_books

  def nick_or_name
    nickname || name
  end

  alias name_no_group nick_or_name

  # a (local) virtual_attribute without a uses, but with arel
  virtual_attribute :nick_or_name, :string, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::NamedFunction.new('COALESCE', [t[:nickname], t[:name]]))
  end)

  # We did not support arel returning something other than Grouping.
  # this is here to test what happens when we do
  virtual_attribute :name_no_group, :string, :arel => (lambda do |t|
    Arel::Nodes::NamedFunction.new('COALESCE', [t[:nickname], t[:name]])
  end)

  def first_book_name
    books.first.name
  end

  def first_book_author_name
    books.first.author_name
  end

  def upper_first_book_author_name
    first_book_author_name.upcase
  end

  # basic attribute with uses that doesn't use a virtual attribute
  def book_with_most_bookmarks
    books.max_by { |book| book.bookmarks.size }
  end

  virtual_has_one :book_with_most_bookmarks, :uses => {:books => :bookmarks}
  # attribute using a relation
  virtual_attribute :first_book_name, :string, :uses => [:books]
  # attribute on a double relation
  virtual_attribute :first_book_author_name, :string, :uses => {:books => :author_name}
  # uses another virtual attribute that uses a relation
  virtual_attribute :upper_first_book_author_name, :string, :uses => :first_book_author_name

  def self.create_with_books(count)
    create!(:name => "foo").tap { |author| author.create_books(count) }
  end

  def create_books(count, create_attrs = {})
    Array.new(count) do
      books.create({:name => "bar"}.merge(create_attrs))
    end
  end
end

class Book < VirtualTotalTestBase
  has_many :bookmarks
  belongs_to :author
  has_and_belongs_to_many :co_authors, :class_name => "Author"
  belongs_to :author_or_bookmark, :polymorphic => true, :foreign_key => "author_id", :foreign_type => "author_type"

  has_many :photos, :as => :imageable, :class_name => "Photo"
  has_one :current_photo, -> { all.merge(Photo.order(:id => :desc)) }, :as => :imageable, :class_name => "Photo"

  scope :ordered,   -> { order(:created_on => :desc) }
  scope :published, -> { where(:published => true)  }
  scope :wip,       -> { where(:published => false) }
  # this tests delegate
  # this also tests an attribute :uses clause with a single symbol
  virtual_delegate :name, :to => :author, :prefix => true
  # delegate to a polymorphic
  virtual_delegate :description, :to => :current_photo, :prefix => true, :type => :string, :allow_nil => true

  # simple uses to a virtual attribute
  virtual_attribute :upper_author_name, :string, :uses => [:author_name]
  virtual_attribute :upper_author_name_def, :string, :uses => :upper_author_name

  def upper_author_name
    author_name.upcase
  end

  def upper_author_name_def
    upper_author_name || "other"
  end

  def self.create_with_bookmarks(count)
    Author.create(:name => "foo").books.create!(:name => "book").tap { |book| book.create_bookmarks(count) }
  end

  def create_bookmarks(count, create_attrs = {})
    Array.new(count) do
      bookmarks.create({:name => "mark"}.merge(create_attrs))
    end
  end
end

class Bookmark < VirtualTotalTestBase
  belongs_to :book
end

class Photo < VirtualTotalTestBase
  belongs_to :imageable, :polymorphic => true
end
