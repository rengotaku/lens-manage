ActiveAdmin.register MLensInfo do
  permit_params :lens_name, :lens_pic_url, :lens_info_url, :stock_state, :price, :m_shop_info_id, :disabled, :memo
  actions :all

  filter :lens_name
  filter :lens_pic_url
  filter :lens_info_url
  filter :stock_state
  filter :price
  filter :m_shop_info_id, as: :select, collection: MShopInfo.all.order(id: :asc).map{ |parent| [parent.shop_name, parent.id] }
  filter :disabled
  filter :memo
  filter :updated_at

  index do
    selectable_column
    column :id do |model_name|
      link_to model_name.id, admin_m_lens_info_path(model_name)
    end

    column :lens_name
    column :lens_pic_url
    column :lens_info_url
    column :stock_state
    column :price

    # # belongs_to でつながっている parent_model のリンク付きの項目
    column :m_shop_info_id do |model_name|
      link_to model_name.m_shop_info.id, admin_m_shop_info_path(model_name.m_shop_info)
    end

    column :disabled
    column :memo
    column :updated_at

    actions defaults: false do |model|
      item 'view', admin_m_lens_info_path(model), class: 'view_link member_link'
      item 'edit', edit_admin_m_lens_info_path(model), class: 'edit_link member_link'
      item 'delete', admin_m_lens_info_path(model), class: 'delete_link member_link', method: :delete, :confirm => "All grades, uploads and tracks will be deleted with this content.Are you sure you want to delete this Content?"
    end
  end

  form do |f|
    f.inputs do
      f.input :lens_name
      f.input :lens_pic_url
      f.input :lens_info_url
      f.input :stock_state
      f.input :price
      f.input :m_shop_info_id, as: :select, collection: MShopInfo.all.map { |model| [model.shop_name, model.id] }
      f.input :disabled
      f.input :memo
    end
    f.actions
  end

  csv humanize_name: false do
    column :id
    column :lens_name
    column :lens_pic_url
    column :lens_info_url
    column :stock_state
    column :price
    column :m_shop_info_id
    column :disabled
    column :memo
  end

  active_admin_importable do |model_c, hash|
    if model_c.exists?(hash[:id])
      @model = model_c.find(hash[:id])
      @model.attributes = hash
      @model.save!
    else
      model_c.create!(hash)
    end
  end
end
