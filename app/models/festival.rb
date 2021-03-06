class Festival < ActiveRecord::Base
  include Organizer
  default_scope { where(:account_id => Account.current_id) }

  attr_accessible :artists_kind, :last_year, :nb_edition, :structure_attributes, :schedulings_attributes, :network_tags, :avatar, :remote_avatar_url

  has_one :structure, as: :structurable, dependent: :destroy
  accepts_nested_attributes_for :structure

  has_many :schedulings, as: :show_host, dependent: :destroy, order: "id ASC"
  has_many :show_buyers, through: :schedulings, uniq: true
  accepts_nested_attributes_for :schedulings, :reject_if => :all_blank, :allow_destroy => true

  delegate :name, :contact, :people, :tasks, :reportings, :remark, :addresses, :emails, :phones, :websites, :city, :address, :network_list, :custom_list, :contacted?, :favorite?, :main_person, to: :structure

  before_save :set_contact_criteria

  mount_uploader :avatar, AvatarUploader

  scope :by_contract, lambda { |tag_name| joins(:schedulings).where("schedulings.contract_tags LIKE ?", "%#{tag_name}%") }
  scope :by_style, lambda { |tag_name| joins(:schedulings).where("schedulings.style_tags LIKE ?", "%#{tag_name}%") }

  def fine_model
    self
  end

  def set_contact_criteria
    self.build_structure unless structure.present?
    self.structure.build_contact unless structure.contact.present?
    contact = structure.contact

    c_style_list = self.style_list
    contact.style_tags = c_style_list.join(',') if c_style_list.present?

    c_contract_list = self.contract_list
    contact.contract_tags = c_contract_list.join(',') if c_contract_list.present?
  end


  def contract_list
    cl = []
    self.schedulings.each do |s|
      s.contract_list.each do |c|
        cl.push(c) unless cl.include?(c)
      end
    end
    cl
  end

  def style_list
    Scheduling.style_for(self)
  end

  def self.from_csv(row)
    festival = Festival.new
    nb_edition = row["nb_editions".to_sym].to_i
    festival.nb_edition = row.delete("nb_editions".to_sym)

    last_edition = row["derniere_annee".to_sym].to_i
    festival.last_year = row.delete("derniere_annee".to_sym)

    scheduling = Scheduling.from_csv(row)
    festival.schedulings << scheduling if scheduling
    festival.structure, invalid_keys = Structure.from_csv(row)
    [festival, invalid_keys]
  end
end
