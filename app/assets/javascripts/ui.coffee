# 可能会用到 turbolinks
# turbolinks 事件加载参考
# https://github.com/rails/turbolinks/#no-jquery-or-any-other-library

###
  图片加载类
###
class Image
  constructor: (@$el)->
    @ave    = @$el.data 'ave' # 平均色值
    @width  = @$el.data 'width' # 原始宽
    @height = @$el.data 'height' # 原始高
    @url    = @$el.data 'url' # 原始地址

    @$el.css
      'position': 'absolute'

    @$ibox = jQuery('<div>')
      .addClass 'ibox'
      .css 
        'background-color': @ave
        'position': 'absolute'
        'top': 0
        'left': 0
        'right': 0
        'bottom': 0
      .appendTo @$el

    if not @$el.hasClass 'aliyun'
      jQuery('<div>')
        .addClass('icheck')
        .appendTo @$el

    jQuery('<a>')
      .addClass('show-detail')
      .attr 
        'href': "/f/#{@$el.data('id')}"
        'target': '_blank'
      .append jQuery('<i>').addClass('fa fa-image')
      .append jQuery('<span>').text '查看详情'
      .appendTo @$el

  get_png_url: (width, height)->
    if @$el.hasClass 'aliyun'
      return "#{@url}@#{width}w_#{height}h_1e_1c"

    "#{@url}?imageMogr2/thumbnail/!#{width}x#{height}r/gravity/Center/crop/#{width}x#{height}"

  pos: (left, top, width, height)->
    @$el.css
      'left'   : @layout_left = left
      'top'    : @layout_top = top
      'width'  : @layout_width = width
      'height' : @layout_height = height

  lazy_load: ->
    return if not @$el.is_in_screen()
    @load()

  load: ->
    return if @loaded
    @loaded = true

    return if not (@layout_width? and @layout_height?)

    w = Math.round @layout_width
    h = Math.round @layout_height

    img = jQuery "<img>"
      .attr 'src', @get_png_url(w, h)
      .attr 'draggable', false
      .css
        'opacity': 0
        'width': '100%'
        'height': '100%'
      .on 'load', =>
        img.animate
          'opacity': 1
        , 400, =>
          @$ibox.css 'background', 'none'
      .appendTo @$ibox

  remove: ->
    @$el.remove()

###
用途：
  图像网格，支持以多种布局来显示图像
  同时支持滚动加载更多图片
用法：
  haml:
    .grid
      .images
        .image{:data => {:url => '', :width => '', :height => '', :ave => ''}}
        .image{:data => {:url => '', :width => '', :height => '', :ave => ''}}
        .image{:data => {:url => '', :width => '', :height => '', :ave => ''}}

  coffee:
    ig = new ImageGrid jQuery('.images'), {
      layout: GridLayout
      viewport: jQuery('.grid')
    }
    ig.relayout()
###
class ImageGrid
  constructor: (@$el, config = {})->
    # @$el 对应 .grid .images
    @$viewport = config.viewport || jQuery(document)
    @layout = new (config.layout || GridLayout) @

    @$el.css
      'position': 'relative'
    
    @image_hash = new OrderedHash
    for dom in @$el.find('.image')
      @append_image jQuery(dom)

    @load_more_url = @$el.data('load-more-url')
    @bind_events()

  bind_events: ->
    @$viewport.on 'scroll', (evt)=>
      @lazy_load_images()
      jQuery(document).trigger 'img4ye:try-loadmore'

    @$viewport.on 'mindpin', ->
      alert(1)

  append_image: ($image)->
    img = new Image $image
    @image_hash.append $image.data('id'), img

  prepend_image: ($image)->
    img = new Image $image
    @image_hash.prepend $image.data('id'), img

  remove_img_ids: (ids)->
    for id in ids
      img = @image_hash.get id
      img.remove()
      @image_hash.del id
    @relayout(true)

  each_image: (func)->
    # for idx in [0 ... @images.length]
    #   func idx, @images[idx] 
    idx = 0
    @image_hash.each (id, img)->
      func idx, img
      idx++

  # 对所有图片重新布局
  relayout: (force = false)->
    @layout.relayout(force)
    setTimeout ->
      jQuery('.grid.nano').nanoScroller {
        alwaysVisible: true
        # flash: true
      }
      jQuery(document).trigger 'img4ye:try-loadmore'

  lazy_load_images: ->
    @image_hash.each (id, img)->
      img.lazy_load()

  get_width: ->
    @$el.width()

  load_more: ->
    return if @$el.hasClass('end') or @$el.hasClass('loading')
    @$el.addClass 'loading'
    
    less_than_id = jQuery('.grid .images .image').last().data('id')

    jQuery.get @load_more_url, { 
      less_than_id: less_than_id 
    }
    .done (res)=>
      $images = jQuery(res).find('.grid .images .image')

      if $images.length
        $images.each (idx, el)=>
          $image = jQuery(el)
          @$el.append $image
          @append_image $image

        @relayout()
        @$el.removeClass 'loading'
      else
        @$el.removeClass 'loading'
        @$el.addClass 'end'

  refresh_stat: (statdata)->
    jQuery('.control .stat')
      .find('span.c.fcount').text(statdata.image_count).end()
      .find('span.c.space').text(statdata.space_used).end()

    if statdata.image_count is 0
      @$el.addClass('blank')
    else
      @$el.removeClass('blank')



# ----------
# 复选图片

class ImageSelector
  constructor: (@$el)->
    @bind_events()

  bind_events: ->
    that = this
    @$el.on 'click', '.image', ->
      jQuery(this).toggleClass('selected')
      that.refresh_selected()

    jQuery('.checkstatus a.check').on 'click', ->
      $checkstatus = jQuery(this).closest('.checkstatus')
      if $checkstatus.hasClass('none') or $checkstatus.hasClass('some')
        that.$el.find('.image').addClass('selected')
        that.refresh_selected()
        return
      if $checkstatus.hasClass('all')
        that.$el.find('.image').removeClass('selected')
        that.refresh_selected()
        return

    @$el.on 'click', '.image a.show-detail', (evt)->
      evt.stopPropagation()

  refresh_selected: ->
    length = @$el.find('.image.selected').length
    all_length = @$el.find('.image').length
    jQuery('.opbar .checkstatus span.n').text length
    jQuery('.opbar .checkstatus').removeClass('none some all')
    if length is 0
      jQuery('.opbar .checkstatus').addClass('none')
    else if length < all_length
      jQuery('.opbar .checkstatus').addClass('some')
    else
      jQuery('.opbar .checkstatus').addClass('all')

    if length > 0
      jQuery('.opbar .btns .bttn').removeClass('disabled')
    else
      jQuery('.opbar .btns .bttn').addClass('disabled')

  get_selected: ->
    @$el.find('.image.selected').closest('.image')


jQuery(document).on 'ready page:load', ->
  jQuery('.image-info.nano').nanoScroller {
    alwaysVisible: true
  }

  if jQuery('.grid .images').length
    window.igrid = new ImageGrid jQuery('.grid .images'), {
      # layout: FlowLayout
      layout: GridLayout
      viewport: jQuery('.grid .nano-content')
    }

    igrid.relayout()

    jQuery(window)
      .off 'resize'
      .on 'resize', -> 
        igrid.relayout()

    ise = new ImageSelector jQuery('.grid .images')

    popbox_delete = new PopBox jQuery('.popbox.template.delete')
    jQuery('.opbar a.bttn.delete').on 'click', ->
      popbox_delete.show ->
        len = ise.get_selected().length
        popbox_delete.$inner.find('span.n').text len
        popbox_delete.bind_ok ->
          ids = for image in ise.get_selected()
            jQuery(image).data('id')
          jQuery.ajax
            url: '/file_entities/batch_delete'
            type: 'DELETE'
            data: 
              ids: ids.join(',')
            success: (res)->
              igrid.remove_img_ids ids
              popbox_delete.close()
              ise.refresh_selected()
              jQuery(document).trigger 'img4ye:file-changed', res.stat


    window.popbox_download = new PopBox jQuery('.popbox.template.download')
    jQuery('.opbar a.bttn.download').on 'click', ->
      popbox_download.show ->
        len = ise.get_selected().length
        popbox_download.$inner.find('span.n').text len
        ids = for image in ise.get_selected()
          jQuery(image).data('id')

        # 发起打包请求
        popbox_download.$inner
          .removeClass 'error success dabao'
          .addClass 'dabao'
        jQuery.ajax
          url: '/file_entities/create_zip'
          type: 'POST'
          data:
            ids: ids.join(',')
          success: (res)->
            $elm = popbox_download.$inner
            $elm.find('.wait').html ''
            test_dabao $elm, res.task_id

    popbox_presets = new PopBox jQuery('.popbox.template.presets'), {
      box_width: '660px'
    }
    jQuery('.stat a.preset-config').on 'click', ->
      desc_str = (preset)->
        switch preset.style
          when 'width_height'
            "宽度 #{preset.width}px, 高度 #{preset.height}px"
          when 'width'
            "宽度 #{preset.width}px, 高度自适应"
          when 'height'
            "高度 #{preset.height}px, 宽度自适应"
          else '???'

      append_preset_dom = ($inner, preset)->
        $inner.find('.records').removeClass('blank')
        $preset = $inner.find('.preset-template').clone()
          .removeClass('preset-template')
          .addClass('preset')
          .attr('data-id', preset.id)
          .show()
          .find('.desc').text(desc_str(preset)).end()
          .appendTo $inner.find('.records .list')

          $inner.find('.rbox.nano').nanoScroller()
          $inner.find('.rbox.nano').nanoScroller {
            alwaysVisible: true
            scroll: 'bottom'
          }
        return $preset

      popbox_presets.show ->
        $inner = popbox_presets.$inner

        # 读取已有配置
        jQuery.ajax
          url: ' /image_sizes'
          type: 'GET'
          success: (res)->
            if res.length is 0
              $inner.find('.records').addClass('blank')
            for preset in res
              append_preset_dom $inner, preset

        popbox_presets.$inner.find('input')
          .first().attr 'checked', true

        $inner.find('.r0 input').on 'change', ->
          $inner.find('input.h').attr('disabled', false).val('')
          $inner.find('input.w').attr('disabled', false).val('')
          $inner.find('a.add').addClass('disabled')

        $inner.find('.r1 input').on 'change', ->
          $inner.find('input.h').attr('disabled', true).val('auto')
          $inner.find('input.w').attr('disabled', false).val('')
          $inner.find('a.add').addClass('disabled')

        $inner.find('.r2 input').on 'change', ->
          $inner.find('input.h').attr('disabled', false).val('')
          $inner.find('input.w').attr('disabled', true).val('auto')
          $inner.find('a.add').addClass('disabled')

        # http://stackoverflow.com/questions/469357/html-text-input-allow-only-numeric-input
        $inner.find('.inputs input')
          .on 'keydown', (evt)->
            key_code = evt.keyCode
            # backspace, delete, tab, escape, enter and .
            if (jQuery.inArray(key_code, [46, 8, 9, 27, 13, 110, 190]) != -1) or
            # ctrl + A
            (key_code is 65 and evt.ctrlKey is true) or
            # ctrl + C
            (key_code is 67 and evt.ctrlKey is true) or
            # ctrl + X
            (key_code is 88 and evt.ctrlKey is true) or
            # home, end, left, right
            (key_code >= 35 and key_code <= 39)
              return

            if ((evt.shiftKey or (key_code < 48 or key_code > 57)) and (key_code < 96 or key_code > 105))
              evt.preventDefault()

          .on 'input', ->
            val = jQuery(this).val()
            jQuery(this).val(3000) if val > 3000

            val1 = $inner.find('input.w').val()
            val2 = $inner.find('input.h').val()

            if (val1 > 0 or val1 is 'auto') and 
            (val2 > 0 or val2 is 'auto')
              $inner.find('a.add').removeClass('disabled')
            else
              $inner.find('a.add').addClass('disabled')

        $inner.find('a.add').on 'click', ->
          return if jQuery(this).hasClass 'disabled'
          $control = jQuery(this).closest('.control')
          style = $control.find('input:checked').val()
          width = $control.find('input.w').val()
          height = $control.find('input.h').val()
          
          data = switch style
            when 'width_height'
              {
                style: style
                width: width
                height: height
              }
            when 'width'
              {
                style: style
                width: width
              }
            when 'height'
              {
                style: style
                height: height
              }

          jQuery.ajax
            url: '/image_sizes'
            type: 'POST'
            data: data
            success: (res)->
              $p = append_preset_dom($inner, res)
                .addClass 'high'
              setTimeout ->
                $p.removeClass('high')
              , 200

        $inner.on 'click', '.preset a.delete', ->
          if confirm '确定要删除这个配置吗？'
            $preset = jQuery(this).closest('.preset')
            id = $preset.data('id')
            jQuery.ajax
              url: "/image_sizes/#{id}"
              type: 'DELETE'
              success: ->
                $preset.hide 200, ->
                  $preset.remove()
                  if $inner.find('.preset').length is 0
                    $inner.find('.records').addClass('blank')

                  $inner.find('.rbox.nano').nanoScroller()
                  $inner.find('.rbox.nano').nanoScroller {
                    alwaysVisible: true
                    scroll: 'bottom'
                  }

    popbox_links = new PopBox jQuery('.popbox.template.links'), {
      box_width: '860px'
    }
    jQuery('.opbar .bttn.copylink').on 'click', ->
      popbox_links.show ->
        len = ise.get_selected().length
        popbox_links.$inner.find('span.n').text len
        ids = for dom in ise.get_selected()
          $image = jQuery(dom)

          $simg = jQuery('<div>')
            .addClass('image')
            .appendTo popbox_links.$inner.find('.w1')
          
          url = "#{$image.data('url')}?imageMogr2/thumbnail/!#{100}x#{100}r/gravity/Center/crop/#{100}x#{100}"

          $ibox = jQuery('<div>')
            .addClass('ibox')
            .css
              'background-image': "url(#{url})"
            .appendTo $simg


          jQuery($image).data('id')

        setTimeout ->
          jQuery('.copylink-images.nano').nanoScroller {
            alwaysVisible: true
          }


        console.log ids

test_dabao = ($elm, task_id)->
  jQuery.ajax
    url: '/file_entities/get_create_zip_task_state'
    type: 'GET'
    data:
      task_id: task_id
    success: (res)->
      return if not window.popbox_download.is_show

      if res.state is 'processing'
        if $elm.find('.wait span').length > 32
          $elm.find('.wait').html ''
        $elm.find('.wait').append jQuery('<span>.</span>')

        setTimeout ->
          test_dabao $elm, task_id
        , 200
        
      if res.state is 'success'
        $elm
          .removeClass 'error success dabao'
          .addClass 'success'

        $elm.find('a.download-zip').attr('href', res.url)
        location.href = res.url

      if res.state is 'failure'
        $elm
          .removeClass 'error success dabao'
          .addClass 'error'


jQuery(document).on 'click', '.preset .field input', ->
  jQuery(this).select()

jQuery(document).on 'click', 'a.close-panel', ->
  $panel = jQuery('.upload-panel')
  $panel.removeClass('opened')
  # 这里先临时放一些视觉效果，集成时要修改
  jQuery('.uploading-images .image').addClass('done')
  jQuery('.uploading-images .image .bar').stop()
    .css
      'width': '100%'
  jQuery('.uploading-images .image .txt .p').text('0')
  jQuery('textarea.urls').val ''

jQuery(document).on 'img4ye:try-loadmore', ->
  if igrid = window.igrid
    igrid.load_more() if igrid.layout.need_load_more()

jQuery(document).on 'img4ye:file-changed', (evt, statdata)->
  window.igrid?.refresh_stat statdata

jQuery(document).on 'img4ye:file-uploaded', (evt, info)->
  if igrid = window.igrid
    $image = jQuery('<div>')
      .addClass('image')
      .attr
        'data-ave': info.ave
        'data-width': info.width
        'data-height': info.height
        'data-url': info.url
        'data-id': info.id

    igrid.$el.prepend $image
    igrid.prepend_image $image
    igrid.relayout(true)