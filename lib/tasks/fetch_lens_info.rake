namespace :fetch_lens_info do
  namespace :all do
    desc "ページ数を全て取得する"
    task page_num: :environment do
      TaskCommon::set_log 'fetch_lens_info/all/page_num'

      MShopInfo.select(:id, :shop_name).where(disabled: true).all.each do |m|
        Rails.logger.info "#{m.shop_name}のページ数を取得"
        Rake::Task["fetch_lens_info:page_num"].invoke(m.id)
      end
    end

    desc "ページ情報を全て取得する"
    task page_info: :environment do
      TaskCommon::set_log 'fetch_lens_info/all/page_info'

      MShopInfo.select(:id, :shop_name).where(disabled: true).all.each do |m|
        Rails.logger.info "#{m.shop_name}のページ情報を取得"
        Rake::Task["fetch_lens_info:page_info"].invoke(m.id)
      end
    end

    desc "画像を全て取得する"
    task lens_image: :environment do
      TaskCommon::set_log 'fetch_lens_info/all/lens_image'

      MShopInfo.select(:id, :shop_name).where(disabled: true).all.each do |m|
        Rails.logger.info "#{m.shop_name}の画像を取得"
        Rake::Task["fetch_lens_info:lens_image"].invoke(m.id)
      end
    end

  end

  desc "ページ数を取得する"
  task :page_num, ['target_shop_id'] => :environment do |task, args|
    TaskCommon::set_log 'fetch_lens_info/page_num'

    TaskSwitchPageNum::fetch args[:target_shop_id].to_i
  end

  desc "ページ情報を取得する"
  task :page_info, ['target_shop_id'] => :environment do |task, args|
    TaskCommon::set_log 'fetch_lens_info/fetch_list'

    TaskSwitchPageInfo::fetch args[:target_shop_id].to_i
  end

  desc "画像を取得する"
  task :lens_image, ['target_shop_id'] => :environment do |task, args|
    m_shop_info = MShopInfo.find(args[:target_shop_id].to_i)
    m_shop_info.m_lens_infos.all.each do |m_lens_info|
      next if MImage.exists?(m_lens_info_id: m_lens_info.id)

      sleep [*2..5].sample # アクセスタイミングを分散させる

      begin
        dir = "#{IMAGE_SAVE_DIR}/#{m_shop_info.id}/"
        img_url = URI.unescape(m_lens_info.lens_pic_url)

        filename = HttpUtils::save_image(img_url, dir).gsub(/(\s|　)+/, '_')
        raise "ファイル拡張子がない" unless File.extname(filename).present?

        ImageDownloadHistory.new(m_shop_info_id: m_shop_info.id, m_lens_info_id: m_lens_info.id, lens_pic_url: m_lens_info.lens_pic_url, status: true).save!

        path = "#{dir}#{filename}"
        MImage.new(m_lens_info_id: m_lens_info.id, path: filename).save!

        # 画像加工
        ConvertUtils::convert_image(path, dir, m_shop_info.shop_name)
      rescue => e
        ImageDownloadHistory.new(m_shop_info_id: m_shop_info.id, m_lens_info_id: m_lens_info.id, lens_pic_url: m_lens_info.lens_pic_url, status: false).save
      end
    end

  end

end
