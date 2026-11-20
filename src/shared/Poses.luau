--[[
	Hand-authored R15 animation poses, as plain numbers so both the game and
	the Lune exporter (tools/anims/build.luau) can read them.
	Each keyframe: { t = seconds, joints = { [PoseName] = { x, y, z, rx, ry, rz } } }
	(offset in studs, rotation in radians, applied as a Motor6D transform).

	Slide: off the rig you skid down the slope after it, leaning back, one leg
	out in front, the other tucked, arms out for balance (owner: "it looks more
	natural than walking fast").
]]

local Poses = {}

Poses.Slide = {
	looped = true,
	priority = "Action",
	keyframes = {
		{ t = 0, joints = {
			LowerTorso = { 0, -0.95, 0, 0.55, 0.35, 0 },
			UpperTorso = { 0, 0, 0, -0.3, -0.2, 0 },
			Head = { 0, 0, 0, -0.25, -0.15, 0 },
			LeftUpperArm = { 0, 0, 0, 0.2, 0, -1.25 },
			LeftLowerArm = { 0, 0, 0, 0.3, 0, 0 },
			RightUpperArm = { 0, 0, 0, -0.3, 0, 1.15 },
			RightLowerArm = { 0, 0, 0, 0.5, 0, 0 },
			RightUpperLeg = { 0, 0, 0, 1.15, 0, 0.1 },
			RightLowerLeg = { 0, 0, 0, -0.15, 0, 0 },
			LeftUpperLeg = { 0, 0, 0, 0.35, 0, -0.15 },
			LeftLowerLeg = { 0, 0, 0, -1.5, 0, 0 },
		} },
		{ t = 0.35, joints = {
			LowerTorso = { 0, -1.0, 0, 0.6, 0.3, 0.05 },
			UpperTorso = { 0, 0, 0, -0.32, -0.15, 0.04 },
			Head = { 0, 0, 0, -0.25, -0.1, 0 },
			LeftUpperArm = { 0, 0, 0, 0.1, 0, -1.4 },
			LeftLowerArm = { 0, 0, 0, 0.2, 0, 0 },
			RightUpperArm = { 0, 0, 0, -0.2, 0, 1.3 },
			RightLowerArm = { 0, 0, 0, 0.4, 0, 0 },
			RightUpperLeg = { 0, 0, 0, 1.1, 0, 0.12 },
			RightLowerLeg = { 0, 0, 0, -0.1, 0, 0 },
			LeftUpperLeg = { 0, 0, 0, 0.4, 0, -0.12 },
			LeftLowerLeg = { 0, 0, 0, -1.45, 0, 0 },
		} },
		{ t = 0.7, joints = "first" }, -- back to the first keyframe, so the loop is seamless
	},
}

-- the R15 joint tree a KeyframeSequence's poses must follow
Poses.TREE = {
	HumanoidRootPart = { "LowerTorso" },
	LowerTorso = { "UpperTorso", "LeftUpperLeg", "RightUpperLeg" },
	UpperTorso = { "Head", "LeftUpperArm", "RightUpperArm" },
	LeftUpperArm = { "LeftLowerArm" },
	LeftLowerArm = { "LeftHand" },
	RightUpperArm = { "RightLowerArm" },
	RightLowerArm = { "RightHand" },
	LeftUpperLeg = { "LeftLowerLeg" },
	LeftLowerLeg = { "LeftFoot" },
	RightUpperLeg = { "RightLowerLeg" },
	RightLowerLeg = { "RightFoot" },
}

-- build a KeyframeSequence with whatever Instance/CFrame/Enum constructors the
-- caller has (Roblox, or Lune's @lune/roblox)
function Poses.build(def, Instance, CFrame, Enum)
	local kfs = Instance.new("KeyframeSequence")
	kfs.Loop = def.looped
	kfs.Priority = Enum.AnimationPriority[def.priority]
	local first = def.keyframes[1].joints
	for _, k in def.keyframes do
		local joints = k.joints == "first" and first or k.joints
		local kf = Instance.new("Keyframe")
		kf.Time = k.t
		local function pose(name: string, parent)
			local p = Instance.new("Pose")
			p.Name = name
			local j = joints[name]
			p.CFrame = j and (CFrame.new(j[1], j[2], j[3]) * CFrame.Angles(j[4], j[5], j[6])) or CFrame.new()
			p.Weight = 1
			p.Parent = parent
			for _, child in Poses.TREE[name] or {} do
				pose(child, p)
			end
		end
		pose("HumanoidRootPart", kf)
		kf.Parent = kfs
	end
	return kfs
end

return Poses
