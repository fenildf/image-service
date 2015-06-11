class Uploader
  constructor: (@$browse_button, @$drag_area_ele, @$files)->
    data = @$browse_button.data()
    @domain = data['domain']
    @basepath = data['basepath']

    # 上传进度显示对象
    @file_progresses = {}
    
    @_init()
    # 注册图片粘贴事件
    new PasteImage (file)=>
      if file?
        file.name = "paste-#{(new Date).valueOf()}.png"
        @qiniu.addFile file

  _init: ()->
    @qiniu = Qiniu.uploader
      runtimes: 'html5,flash,html4'
      browse_button: @$browse_button.get(0),
      uptoken_url: '/file_entities/uptoken',
      domain: @domain,
      max_file_size: '100mb',
      max_retries: 1,
      dragdrop: true,
      drop_element: @$drag_area_ele.get(0),
      chunk_size: '4mb',
      auto_start: true,
      x_vars:
        origin_file_name: (up, file)->
          file.name
      init:
        ###
          文档参考：
          http://developer.qiniu.com/docs/v6/sdk/javascript-sdk.html
        ###

        # 指定七牛文件 key 的个性化生成规则
        # 该方法首先被触发
        Key: (up, file)=>
          ext = file.name.split(".").pop()
          ext = ext.toLowerCase()
          "/#{@basepath}/#{jQuery.randstr()}.#{ext}"

        # 该方法第二个被触发
        BeforeUpload: (up, file)=>
          console.debug 'before upload'
          if not @file_progresses[file.id]?
            @file_progresses[file.id] = new FileProgress(file, up)

        # 该方法第三个被触发，上传结束前持续被触发
        UploadProgress: (up, file)=> 
          console.debug 'upload progress'
          chunk_size = plupload.parseSize up.getOption('chunk_size')
          @file_progresses[file.id].update()
          # 当前进度 #{file.percent}%，
          # 速度 #{up.total.bytesPerSec}，

        # 该方法在上传成功结束时触发
        FileUploaded: (up, file, info_json)=>
          console.debug 'file uploaded'
          info = jQuery.parseJSON(info_json);
          @file_progresses[file.id].success(info)

        # 该方法在上传出错时触发
        Error: (up, err, errTip)=>
          @file_progresses[err.file.id].error()

        # 同时选择多个文件时才会触发
        FilesAdded: (up, files)=>
          console.debug 'many files'
          plupload.each files, (file)=>
            if not @file_progresses[file.id]?
              @file_progresses[file.id] = new FileProgress(file, up)

        # 该方法在整个队列处理完毕后触发
        UploadComplete: ->
          #队列文件处理完毕后,处理相关的事情

###
  用于显示上传进度的类
  里面规定了上传进度如何被显示的一些方法
###
class FileProgress
  constructor: (qiniu_uploading_file, @uploader)->
    @file = qiniu_uploading_file
    console.log @file
    window.afile = @file

    @ready()

  # 当文件开始上传的瞬间，会执行这个方法
  # 一般用于进行界面变化，DOM 准备等操作
  ready: ->
    @_open_panel()
    @_make_dom()

  _open_panel: ->
    $panel = jQuery('.upload-panel')
    return if $panel.hasClass('opened')
    $panel.addClass('opened')
    setTimeout ->
      jQuery('.uploading-images.nano').nanoScroller {
        alwaysVisible: true
      }
    , 1

  _make_dom: ->
    console.log 'make dom'
    @$dom = jQuery('.uploading-images .template-image')
      .clone().show()
      .removeClass('template-image').addClass('image')
      .appendTo jQuery('.uploading-images .w1')

    reader = new FileReader()
    reader.readAsDataURL @file.getNative()
    reader.onload = (e)=>
      @$dom.find('.ibox').css
        'background-image': "url(#{e.target.result})"

    ## 绑定取消上传事件
    @$dom.on 'click', '.cancel', =>
      @uploader.removeFile @file
      @$dom.hide 300, =>
        @$dom.remove()

  # 上传进度进度更新时调用此方法
  update: ->
    @$dom.find('.bar')
      .stop()
      .animate {
        'width': "#{100 - @file.percent}%"
      }, {
        step: (num)=>
          text = @$dom.find('.txt .p').text()
          percent = 100 - Math.ceil num
          @$dom.find('.txt .p').text percent if percent > text
      }

  # 上传成功时调用此方法
  success: (info)->
    @$dom.addClass('done').data('url', info.url)
    arr = []
    jQuery('.uploading-images .image.done').each ->
      arr.push jQuery(this).data('url')
    jQuery('textarea.urls').val arr.join("\n")

    # 处理页面上的统计信息显示
    console.log info
    jQuery(document).trigger 'img4ye:file-changed', info.stat

  # 上传出错时调用此方法
  error: ->
    @$dom.addClass('error')


jQuery(document).on 'ready page:load', ->
  if jQuery('.btn-upload').length
    $browse_button = jQuery('.btn-upload')
    $dragdrop_area = jQuery(document.body)
    new Uploader($browse_button, $dragdrop_area)