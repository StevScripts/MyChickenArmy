--!strict
-- Bake one seamless, detailed field per active appearance. Animation scrolls
-- this image with native drawing; no noise/pixel loop runs on the render clock.
local AssetService = game:GetService("AssetService")
local Pattern = {}
local EDGE = 512

local function hash(x: number, y: number, seed: number): number
	local n = bit32.bxor(x * 374761393 + y * 668265263 + seed * 1013904223, 0)
	n = bit32.bxor(n, bit32.rshift(n, 13))
	return (n % 65536) / 65535
end

local function noise(u: number, v: number, period: number, seed: number): number
	local x,y=u*period,v*period
	local ix,iy=math.floor(x),math.floor(y)
	local fx,fy=x-ix,y-iy
	fx,fy=fx*fx*(3-2*fx),fy*fy*(3-2*fy)
	local a,b=hash(ix%period,iy%period,seed),hash((ix+1)%period,iy%period,seed)
	local c,d=hash(ix%period,(iy+1)%period,seed),hash((ix+1)%period,(iy+1)%period,seed)
	return (a+(b-a)*fx)*(1-fy)+(c+(d-c)*fx)*fy
end

function Pattern.Create(appearance: string, current: () -> boolean): EditableImage?
	local pixels=buffer.create(EDGE*EDGE*4)
	for y=0,EDGE-1 do
		local v=y/EDGE
		for x=0,EDGE-1 do
			local color: Color3
			if appearance=="Rainbow" then
				color=Color3.fromHSV(v,0.88,1)
			else
				local u=x/EDGE
				local f=noise(u,v,4,17)*0.48+noise(u,v,8,29)*0.27
					+noise(u,v,16,41)*0.15+noise(u,v,32,53)*0.07+noise(u,v,64,67)*0.03
				local wave=(math.sin(math.pi*2*(u*2+v)+f*7)+1)*0.5
				local band=math.clamp((wave-0.28)/0.72,0,1)^2
				local base=Color3.fromRGB(5,8,27):Lerp(Color3.fromRGB(24,37,102),f)
				local cloud=Color3.fromRGB(68,36,151):Lerp(Color3.fromRGB(184,99,219),f)
				color=base:Lerp(cloud,band)
				local cyan=math.clamp((noise(u,v,8,83)-0.52)*3,0,0.5)*band
				color=color:Lerp(Color3.fromRGB(70,177,215),cyan)
			end
			local offset=(y*EDGE+x)*4
			buffer.writeu8(pixels,offset,math.round(color.R*255))
			buffer.writeu8(pixels,offset+1,math.round(color.G*255))
			buffer.writeu8(pixels,offset+2,math.round(color.B*255))
			buffer.writeu8(pixels,offset+3,255)
		end
		if y%32==31 then task.wait();if not current() then return nil end end
	end
	if appearance=="Galaxy" then
		-- Subpixel-sized source stars stay points instead of the old large squares.
		local random=Random.new(28117)
		for index=1,210 do
			local x,y=random:NextInteger(0,EDGE-1),random:NextInteger(0,EDGE-1)
			local brightness=random:NextInteger(175,255)
			local offset=(y*EDGE+x)*4
			buffer.writeu32(pixels,offset,brightness+brightness*256+255*65536+255*16777216)
			if index%12==0 then
				for _,delta in {Vector2.new(-1,0),Vector2.new(1,0),Vector2.new(0,-1),Vector2.new(0,1)} do
					local p=(((y+delta.Y)%EDGE)*EDGE+(x+delta.X)%EDGE)*4
					buffer.writeu32(pixels,p,130+150*256+205*65536+255*16777216)
				end
			end
		end
	end
	if not current() then return nil end
	local image=AssetService:CreateEditableImage({Size=Vector2.new(EDGE,EDGE)})
	assert(image,"Pattern image budget unavailable")
	image:WritePixelsBuffer(Vector2.zero,image.Size,pixels)
	return image
end

return Pattern
