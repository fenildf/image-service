window.PresetPopboxAdapter = class PresetPopboxAdapter
  constructor: (@popbox)->
    @popbox.run_adapter @

  on_show: ($inner)->
    @$inner = $inner

    # 读取已有配置
    @load_presets()

    # 默认选中第一个
    @find('input').first().attr 'checked', true

    # 设置选中 radio 事件
    @bind_radio_events()

    # 设置限制输入
    @limit_input_number()

    # 注册增加事件
    @bind_add_event()

    # 注册删除事件
    @bind_delete_event()
    

  find: (str)->
    @$inner.find(str)

  load_presets: ->
    jQuery.ajax
      url: ' /image_sizes'
      type: 'GET'
      success: (res)=>
        if res.length is 0
          @find('.records').addClass('blank')
        for preset in res
          @append_preset_dom preset


  append_preset_dom: (preset)->
    @find('.records').removeClass('blank')
    $preset = @find('.preset-template').clone()
      .removeClass('preset-template')
      .addClass('preset')
      .attr('data-id', preset.id)
      .show()
      .find('.desc').text(preset.name).end()
      .appendTo @find('.records .list')
    @refresh_nano()
    return $preset

  refresh_nano: ->
    @find('.rbox.nano')
      .nanoScroller()
      .nanoScroller {
        alwaysVisible: true
        scroll: 'bottom'
      }

    # 刷新页面配置数显示
    jQuery('.stat .c.sizes').text @find('.preset').length

  bind_radio_events: ->
    @$inner.on 'change', '.r0 input', =>
      @find('input.h').attr('disabled', false).val('')
      @find('input.w').attr('disabled', false).val('')
      @find('a.add').addClass('disabled')

    @$inner.on 'change', '.r1 input', =>
      @find('input.h').attr('disabled', true).val('auto')
      @find('input.w').attr('disabled', false).val('')
      @find('a.add').addClass('disabled')

    @$inner.on 'change', '.r2 input', =>
      @find('input.h').attr('disabled', false).val('')
      @find('input.w').attr('disabled', true).val('auto')
      @find('a.add').addClass('disabled')

  limit_input_number: ->
    # 参考此帖实现
    # http://stackoverflow.com/questions/469357/html-text-input-allow-only-numeric-input
    that = this
    @$inner
      .on 'keydown', '.inputs input', (evt)->
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

      .on 'input', '.inputs input', ->
        val = jQuery(this).val()
        jQuery(this).val(3000) if val > 3000

        val1 = that.find('input.w').val()
        val2 = that.find('input.h').val()

        if (val1 > 0 or val1 is 'auto') and 
        (val2 > 0 or val2 is 'auto')
          that.find('a.add').removeClass('disabled')
        else
          that.find('a.add').addClass('disabled')

  bind_add_event: ->
    that = this
    @$inner.on 'click', 'a.add', ->
      return if jQuery(this).hasClass 'disabled'
      $control = jQuery(this).closest('.control')

      style  = that.find('input:checked').val()
      width  = that.find('input.w').val()
      height = that.find('input.h').val()
      
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
          $p = that
            .append_preset_dom(res)
            .hide()
            .fadeIn 300

  bind_delete_event: ->
    that = this
    @$inner.on 'click', '.preset a.delete', ->
      if confirm '确定要删除这个配置吗？'
        $preset = jQuery(this).closest('.preset')
        id = $preset.data('id')
        jQuery.ajax
          url: "/image_sizes/#{id}"
          type: 'DELETE'
          success: ->
            $preset.fadeOut 300, ->
              $preset.remove()
              if that.find('.preset').length is 0
                that.find('.records').addClass('blank')
              that.refresh_nano()

window.DeletePopboxAdapter = class DeletePopboxAdapter
  constructor: (@popbox, @iselector)->
    @popbox.run_adapter @

  find: (str)->
    @$inner.find(str)

  on_show: ($inner)->
    @$inner = $inner

    @find('span.n').text @iselector.get_selected().length
    @popbox.bind_ok =>
      ids = @iselector.get_selected_ids()

      jQuery.ajax
        url: '/file_entities/batch_delete'
        type: 'DELETE'
        data: 
          ids: ids.join(',')
        success: (res)=>
          igrid.remove_img_ids ids
          @popbox.close()
          @iselector.refresh_selected()
          jQuery(document).trigger 'img4ye:file-changed', res.stat



window.DownloadPopboxAdapter = class DownloadPopboxAdapter
  constructor: (@popbox, @iselector)->
    @popbox.run_adapter @

  find: (str)->
    @$inner.find(str)

  on_show: ($inner)->
    @$inner = $inner

    @find('span.n').text @iselector.get_selected().length
    ids = @iselector.get_selected_ids()

    # 发起打包请求
    @$inner
      .removeClass 'error success dabao'
      .addClass 'dabao'

    jQuery.ajax
      url: '/file_entities/create_zip'
      type: 'POST'
      data:
        ids: ids.join(',')
      success: (res)=>
        @find('.wait').html ''
        @test_dabao res.task_id

  test_dabao: (task_id)->
    jQuery.ajax
      url: '/file_entities/get_create_zip_task_state'
      type: 'GET'
      data:
        task_id: task_id
      success: (res)=>
        return if not @popbox.is_show

        if res.state is 'processing'
          if @find('.wait span').length > 32
            @find('.wait').html ''
          @find('.wait').append jQuery('<span>.</span>')

          setTimeout =>
            @test_dabao task_id
          , 200
          
        if res.state is 'success'
          @$inner
            .removeClass 'error success dabao'
            .addClass 'success'

          @find('a.download-zip').attr('href', res.url)
          location.href = res.url

        if res.state is 'failure'
          @$inner
            .removeClass 'error success dabao'
            .addClass 'error'


window.LinksPopboxAdapter = class LinksPopboxAdapter
  constructor: (@popbox, @iselector)->
    @popbox.run_adapter @

  find: (str)->
    @$inner.find(str)

  on_show: ($inner)->
    @$inner = $inner
    @generate_images()

    lf = new LinksForm @find('.linksform'), =>
      @urls

    lf.load_presets()

    # @load_presets()
    # @bind_selector_events()

  generate_images: ->
    len = @iselector.get_selected().length
    @urls = []
    for dom in @iselector.get_selected()
      $image = jQuery(dom)

      @urls.push $image.data('url')

      $simg = jQuery('<div>')
        .addClass('image')
        .appendTo @find('.w1')
      
      url = "#{$image.data('url')}?imageMogr2/thumbnail/!#{100}x#{100}r/gravity/Center/crop/#{100}x#{100}"

      $ibox = jQuery('<div>')
        .addClass('ibox')
        .css
          'background-image': "url(#{url})"
        .appendTo $simg

    jQuery('.copylink-images.nano')
      .nanoScroller()
      .nanoScroller {
        alwaysVisible: true
      }

window.LinksForm = class LinksForm
  constructor: (@$form, @urls_func)->
    @bind_selector_events()

  load_presets: ->
    jQuery.ajax
      url: ' /image_sizes'
      type: 'GET'
      success: (res)=>
        @$form.find('select.presets option').each ->
          $option = jQuery(this)
          $option.remove() if $option.data('preset')?

        for preset in res
          @add_select_option preset

        @show_urls()

  add_select_option: (preset)->
    $select = @$form.find('select.presets')
    $option = jQuery('<option>')
      .text(preset.name)
      .data 'preset', preset
      .appendTo $select

  show_urls: (preset, kind)->
    results = for url in @urls_func()
      u = if not preset?
            url
          else
            QiniuURLFormater.format {
              url: url
              style: preset.style
              width: preset.width
              height: preset.height
            }

      switch kind
        when 'html'
          "<img src='#{u}' />"
        when 'md'
          "![](#{u})"
        when 'bbcode'
          "[img]#{u}[/img]"
        else
          u

    @$form.find('textarea').val results.join("\n")

  bind_selector_events: ->
    @$form.on 'change', 'select', =>
      @update_urls()

  update_urls: ->
    preset = @$form.find('select.presets option:selected')
      .data('preset')
    kind = @$form.find('select.kind').val()
    console.debug kind
    @show_urls preset, kind