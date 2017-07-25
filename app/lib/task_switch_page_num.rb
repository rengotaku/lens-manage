class TaskSwitchPageNum
  # Capybara初期設定
  def self.switch(shop_id)
    $shop_id = shop_id
    if shop_id == 1 # レモン社
      target_1
    elsif shop_id == 2 # モリッツ
      target_2
    elsif shop_id == 999
      # コピー用
    else
      raise "#{shop_id}"
    end
  rescue => e
    raise "m_shop_info_idが#{e.message}のページ数が取得できませんでした。"
  end

  private

  # レモン社
  def self.target_1
    page_pattern = Regexp.new("p=(\\d+)")

    collect_targets = CollectTarget.where(m_shop_info_id: $shop_id).all

    session = TaskCommon::get_session

    collect_targets.each do |collect_target|
      # 対象URLに遷移する
      session.visit collect_target.list_url.gsub(/\[\$page\]/, '1')

      # 全てのアンカーを取得する 
      session.all(:css, '.navipage_ .navipage_last_ a').each do |anchor|
        if anchor[:href] =~ page_pattern
          collect_target.start_page_num = 1
          collect_target.end_page_num = $1
        else
          raise "#{$shop_id}"
        end
      end

      collect_target.save!
    end
  end

  # モリッツ
  def self.target_2
    collect_targets = CollectTarget.where(m_shop_info_id: $shop_id).all

    collect_targets.each do |collect_target|
      collect_target.start_page_num = 1
      collect_target.end_page_num = 1

      collect_target.save!
    end
  end

  
end