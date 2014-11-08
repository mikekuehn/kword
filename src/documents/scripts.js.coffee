aspect = 0
char = {}
subpixels = 1

drawCharacterSet = ->

	fontFamily = $('#font_family').val()
	fontSize = $('#font_size').val()
	subpixels = $('#subpixels').val()
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
		for j in [0...lines[i].length]
			for y in [0...subpixels]
				for x in [0...subpixels]				##bugs here!!!
					imgData = chars.getImageData(\
						char.width * (j + y / subpixels), \
						char.height * (i + y / subpixels), \
						char.width / subpixels, char.height / subpixels)
					weight = 0 # subpixel weight
					for p in [3...imgData.data.length] by 4
						weight += imgData.data[p]
					window.weights.push {darkness:weight,character:lines[i][j],y:y,y:y}

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

entityMap =
	"&": "&amp;"
	"<": "&lt;"
	">": "&gt;"
	'"': '&quot;'
	"'": '&#39;'
	"/": '&#y2F;'

escapeHtml = (string) ->
	return String(string).replace(/[&<>"'\/]/g, (s) -> return entityMap[s])

imgToText = ->
	source = document.getElementById("adjust_image")
	cvs = source.getContext('2d')
	ditherFine = document.getElementById('dither_fine').checked
	ditherWide = document.getElementById('dither_wide').checked
	gr = greyscale(source) # array of pixel values
	fontFamily = $('#font_family').val()
	fontSize = $('#font_size').val()
	$('#output_ascii').css('font-family',fontFamily)\
		.css('font-size',fontSize+'px')\
		.css('line-height',fontSize*$('#line_height').val()+'px')
	text = ''
	[h,w] = [source.height,source.width]
	sp = subpixels
	autoSp = true
	for i in [0...h/sp] # loop through 'character grid' rows
		row = ''
		for j in [0...w/sp] # loop through 'character grid' cols
			compare = []

			# loop through character weights, subpixels
			for ch in [0...window.weights.length] by sp*sp
				grD = [] # character pixel values (for dithering)
				for y in [0...sp] # subpixel y
					for x in [0...sp] # subpixel x
						grD.push(gr[i*w*sp + j*sp + y + x*w])
				for y in [0...sp] # subpixel y
					for x in [0...sp] # subpixel x
						b = grD[y*sp+x]
						c = window.weights[ch+y*sp+x]
						thisChar = _.find(compare, (n) ->
							return n.character is c.character
						)
						if thisChar is undefined
							compare.push({character:c.character,err:[]})
							thisChar = _.find(compare, (n) ->
								return n.character is c.character
							)
						err = c.brightness - b
						thisChar.err.push err

						# subpixel dithering
						# grD[y*sp+x] = c.brightness
						if ditherFine
							if y+1 < sp
								grD[y*sp+x+1] += (err * 7/16)
							if x+1 < sp and y-1 > 0
								grD[(y+1)*sp + x-1] += (err * 3/16)
							if x+1 < sp
								grD[(y+1)*sp + x] += (err * 5/16)
							if x+1 < sp and y+1 < sp
								grD[(y+1)*sp + j+1] += (err * 1/16)

			# now pick the closest shape based on total error summation
			for c in compare
				c.shapeErr = 0
				c.colorErr = 0
				for err in c.err
					c.shapeErr += Math.abs(err)
					c.colorErr += err
			bestChoice = _.min(compare,(w) -> w.shapeErr)

			# don't forget to dither again
			if ditherWide
				err = bestChoice.err # microdither! :)
				for y in [0...sp]
					for x in [0...sp]
						#gr[i*w*sp + j*sp + y + x*w]
						if j+1 < w/sp # right side
							gr[sp*(i*w+j+1)+y*w+x] += (err[y*sp+x] * 7/16)
						if i+1 < h/sp and j-1 > 0 # left bottom
							gr[sp*(w*(i+1)+j-1)+y*w+x] += (err[y*sp+x] * 3/16)
						if i+1 < h/sp # bottom
							gr[sp*(w*(i+1)+j)+y*w+x] += (err[y*sp+x] * 5/16)
						if i+1 < h/sp and j+1 < w/sp # bottom right
							gr[sp*(w*(i+1)+j+1)+y*w+x] += (err[y*sp+x] * 1/16)

			# append best character to row
			row += bestChoice.character

		#append row to output ASCII
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
		cty = canvas.getContext("2d")
		aspectRatio = image.height/image.width
		canvas.width = rowLength * subpixels
		canvas.height = rowLength*aspectRatio*aspect * subpixels
		cty.drawImage(image, 0, 0, canvas.width, canvas.height)
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

$('#subpixels').change ->
	drawCharacterSet()
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

$('#shape_val').change ->
	if theImage != ''
		render(theImage)

$('#color_val').change ->
	if theImage != ''
		render(theImage)

$('form').submit ->
	return false

$('#bw').change ->
	if theImage != ''
		render(theImage)

$('#dither_fine').change ->
	if theImage != ''
		render(theImage)

$('#dither_wide').change ->
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

