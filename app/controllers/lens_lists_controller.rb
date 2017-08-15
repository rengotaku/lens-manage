class LensListsController < ApplicationController
  layout "to_c"
  before_action :init_setting

  def top
    @m_lens_infos = LensListsService.top
  end

  def index
    @title = 'レンズを探す'
    if @q = params[:q]
      @m_lens_infos = LensListsService.index(params[:q], params[:page])
      @q = params[:q]
    end
  end

  def about
    @title = 'サイトについて'
    
  end

  def contact
    @title = 'お問い合わせ'
    
  end

  private 
  def init_setting
    @title = 'トップ'
  end

end
