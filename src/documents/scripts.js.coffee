aspect = 0
char = {}

drawCharacterSet = ->

	fontFamily = $('#font_family').val()
	fontSize = $('#font_size').val()
	chars_canvas = document.getElementById('character_set')
	chars_canvas.width = chars_canvas.width
	chars = chars_canvas.getContext('2d')
	if document.getElementById('for_print').checked
		fontSize = 72
	chars.font = fontSize + 'px ' + fontFamily
	chars.textBaseline = 'bottom'
	char =
		width: chars.measureText('.').width
		height: fontSize * 1.5
	aspect = (char.width / fontSize) / $('#line_height').val()
	lines = $('#char_set').val()
	window.weights = []
	for i in [0...lines.length]
		chars.fillText lines[i], 0, char.height*(i+1)
		for j in [0...lines[i].length] by 1
			imgData = chars.getImageData(\
				char.width * j, char.height * i, \
				char.width, char.height )
			weight = 0
			for p in [3...imgData.data.length] by 4
				weight += imgData.data[p]
			window.weights.push {img:imgData,darkness:weight,\
				character:lines[i][j]}
	for i in [0...lines.length] by 1
		for j in [0...lines[i].length]
			chars.strokeStyle = '#ffff00'
			chars.beginPath()
			chars.moveTo(char.width * j, char.height * i)
			chars.lineTo(char.width * (j+1), char.height * i)
			chars.lineTo(char.width * (j+1), char.height * (i+1) )
			chars.lineTo(char.width * (j), char.height * (i+1) )
			chars.lineTo(char.width * j, char.height * i)
			chars.stroke() 
	window.weights = _(window.weights).sortBy('darkness')
	maxWeight = _.max(window.weights,(w) -> w.darkness).darkness
	minWeight = _.min(window.weights,(w) -> w.darkness).darkness
	for w in window.weights
		w.brightness = 255 - (255*(w.darkness-minWeight))/(maxWeight-minWeight)
	drawGradient()

drawGradient = ->

	console.log('to-do: gradient code')

entityMap =
	"&": "&amp;"
	"<": "&lt;"
	">": "&gt;"
	'"': '&quot;'
	"'": '&#39;'
	"/": '&#x2F;'

escapeHtml = (string) ->
	return String(string).replace(/[&<>"'\/]/g, (s) -> return entityMap[s])

imgToText = ->
	source = document.getElementById("adjust_image")
	cvs = source.getContext('2d')
	dither = document.getElementById('dithering').checked
	gr = greyscale(source)
	fontFamily = $('#font_family').val()
	fontSize = $('#font_size').val()
	$('#output_ascii').css('font-family',fontFamily)\
		.css('font-size',fontSize+'px')\
		.css('line-height',fontSize*$('#line_height').val()+'px')
	text = ''
	[h,w] = [source.height,source.width]
	for i in [0...h]
		row = ''
		for j in [0...w]
			b = gr[i*w + j]
			# find closest ascii brightness value
			closest = null
			for c in window.weights
				if closest is null or Math.abs(c.brightness-b) < Math.abs(err)
					closest = c
					err = b-c.brightness
			# floyd-steinberg dithering
			if dither
				gr[i*w + j] = c.brightness
				if j+1 < w
					gr[i*w + j+1] += (err * 7/16)
				if i+1 < h and j-1 > 0
					gr[(i+1)*w + j-1] += (err * 3/16)
				if i+1 < h
					gr[(i+1)*w + j] += (err * 5/16)
				if i+1 < h and j+1 < w
					gr[(i+1)*w + j+1] += (err * 1/16)
			row += closest.character
		text += escapeHtml(row) + '<br />'
	$('#output_ascii').html(text)

greyscale = (canvas) ->
	greyscaleMethod = $('#bw').val()
	customR = $('#customR').val()
	customG = $('#customG').val()
	customB = $('#customB').val()
	greyArray = []
	cvs = canvas.getContext('2d')
	imgData = cvs.getImageData(0,0,canvas.width,canvas.height)
	imgData = imgData.data
	for p in [0...imgData.length] by 4
		l = 0
		if greyscaleMethod is 'ccir'
			[r,g,b] = [0.2989, 0.5870, 0.1140]
		else if greyscaleMethod is 'cie'
			[r,g,b] = [0.2126, 0.7152, 0.0722]
		else if greyscaleMethod is 'flat'
			[r,g,b] = [0.3333, 0.3333, 0.3333]
		else if greyscaleMethod is 'red'
			[r,g,b] = [1, 0, 0]
		else if greyscaleMethod is 'green'
			[r,g,b] = [0, 1, 0]
		else if greyscaleMethod is 'blue'
			[r,g,b] = [0, 0, 1]
		l += imgData[p] * r * customR * imgData[p+3] / 255 #Red
		l += imgData[p+1] * g * customG * imgData[p+3] / 255 #Green
		l += imgData[p+2] * b * customB * imgData[p+3] / 255 #Blue
		greyArray.push(l)
	return greyArray

render = (src) ->
	image = new Image();
	image.onload = ->
		rowLength = $('#row_length').val()
		canvas = document.getElementById("adjust_image")
		ctx = canvas.getContext("2d")
		aspectRatio = image.height/image.width
		canvas.width = rowLength
		canvas.height = rowLength*aspectRatio*aspect
		ctx.drawImage(image, 0, 0, canvas.width, canvas.height)
		imgToText()
	image.src = src

theImage = ''

loadImage = (src) ->
	# Prevent any non-image file type from being read.
	if !src.type.match(/image.*/)
		console.log("The dropped file is not an image: ", src.type)
		return

	# Create our FileReader and run the results through the render function.
	reader = new FileReader()
	reader.onload = (e) ->
		theImage = e.target.result
		render(theImage)
	reader.readAsDataURL(src)

# Drag and drop listeners

target = document.getElementById("container")
target.addEventListener("dragover", (e) ->
	e.preventDefault()
, true)
target.addEventListener("drop", (e) ->
	e.preventDefault()
	loadImage(e.dataTransfer.files[0])
, true)

$('document').ready ->
	drawCharacterSet()
	$('#output_ascii').draggable()

$('#font_family').change ->
	drawCharacterSet()
	if theImage != ''
		render(theImage)

$('#char_set').change ->
	drawCharacterSet()
	if theImage != ''
		render(theImage)

$('#font_size').change ->
	drawCharacterSet()
	if theImage != ''
		render(theImage)

$('#row_length').change ->
	if theImage != ''
		render(theImage)

$('#customR').change ->
	if theImage != ''
		render(theImage)

$('#customG').change ->
	if theImage != ''
		render(theImage)

$('#customB').change ->
	if theImage != ''
		render(theImage)

$('form').submit ->
	return false

$('#bw').change ->
	if theImage != ''
		render(theImage)

$('#dithering').change ->
	if theImage != ''
		render(theImage)

$('#line_height').change ->
	aspect = (char.width / (char.height / 1.5)) / $(this).val()
	if theImage != ''
		render(theImage)

$('#for_print').change ->
	drawCharacterSet()
	if theImage != ''
		render(theImage)

