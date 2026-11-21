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

-- Tool use (owner: "clicking should also swing the pickaxe", "everything should
-- be animated"). These key only the upper body (partial), so the legs keep
-- walking underneath. Positive rx on an upper arm raises it forward; the tool's
-- business end points forward when the arm is level (rx = 1.5).

-- Pickaxe: wind up over the shoulder, chop down, come back to the hold
Poses.Swing = {
	priority = "Action4",
	partial = true,
	keyframes = {
		{ t = 0, joints = {
			UpperTorso = { 0, 0, 0, 0, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.5, 0, 0 },
			RightLowerArm = { 0, 0, 0, 0.2, 0, 0 },
		} },
		{ t = 0.14, joints = {
			UpperTorso = { 0, 0, 0, -0.18, 0.25, 0 },
			RightUpperArm = { 0, 0, 0, 2.9, 0, 0.15 },
			RightLowerArm = { 0, 0, 0, 0.9, 0, 0 },
		} },
		{ t = 0.27, joints = {
			UpperTorso = { 0, 0, 0, 0.3, -0.15, 0 },
			RightUpperArm = { 0, 0, 0, 0.55, 0, -0.1 },
			RightLowerArm = { 0, 0, 0, 0.05, 0, 0 },
		} },
		{ t = 0.5, joints = "first" },
	},
}

-- Crank Pump: both hands pump the handle down and up
Poses.Crank = {
	priority = "Action4",
	partial = true,
	keyframes = {
		{ t = 0, joints = {
			UpperTorso = { 0, 0, 0, 0.1, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.5, 0, 0 },
			RightLowerArm = { 0, 0, 0, 0.2, 0, 0 },
			LeftUpperArm = { 0, 0, 0, 1.3, 0, 0.45 },
			LeftLowerArm = { 0, 0, 0, 0.3, 0, 0 },
		} },
		{ t = 0.15, joints = {
			UpperTorso = { 0, 0, 0, 0.35, 0, 0 },
			RightUpperArm = { 0, 0, 0, 0.8, 0, 0 },
			RightLowerArm = { 0, 0, 0, 0.1, 0, 0 },
			LeftUpperArm = { 0, 0, 0, 0.7, 0, 0.45 },
			LeftLowerArm = { 0, 0, 0, 0.2, 0, 0 },
		} },
		{ t = 0.38, joints = "first" },
	},
}

-- Delver's Hook: rod back over the shoulder, then whip it forward
Poses.Cast = {
	priority = "Action4",
	partial = true,
	keyframes = {
		{ t = 0, joints = {
			UpperTorso = { 0, 0, 0, 0, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.5, 0, 0 },
			RightLowerArm = { 0, 0, 0, 0.2, 0, 0 },
		} },
		{ t = 0.16, joints = {
			UpperTorso = { 0, 0, 0, -0.2, 0.3, 0 },
			RightUpperArm = { 0, 0, 0, 2.95, 0, 0.1 },
			RightLowerArm = { 0, 0, 0, 0.7, 0, 0 },
		} },
		{ t = 0.3, joints = {
			UpperTorso = { 0, 0, 0, 0.25, -0.1, 0 },
			RightUpperArm = { 0, 0, 0, 1.15, 0, 0 },
			RightLowerArm = { 0, 0, 0, 0, 0, 0 },
		} },
		{ t = 0.55, joints = "first" },
	},
}

-- Delver's Hook: a sharp yank back to reel in
Poses.Reel = {
	priority = "Action4",
	partial = true,
	keyframes = {
		{ t = 0, joints = {
			UpperTorso = { 0, 0, 0, 0, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.5, 0, 0 },
			RightLowerArm = { 0, 0, 0, 0.2, 0, 0 },
		} },
		{ t = 0.1, joints = {
			UpperTorso = { 0, 0, 0, -0.25, 0.1, 0 },
			RightUpperArm = { 0, 0, 0, 2.5, 0, 0 },
			RightLowerArm = { 0, 0, 0, 1.0, 0, 0 },
		} },
		{ t = 0.36, joints = "first" },
	},
}

-- Food: hand to mouth, two bites
Poses.Eat = {
	priority = "Action4",
	partial = true,
	keyframes = {
		{ t = 0, joints = {
			Head = { 0, 0, 0, 0, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.5, 0, 0 },
			RightLowerArm = { 0, 0, 0, 0.2, 0, 0 },
		} },
		{ t = 0.18, joints = {
			Head = { 0, 0, 0, 0.15, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.1, 0, -0.55 },
			RightLowerArm = { 0, 0, 0, 1.9, 0, 0 },
		} },
		{ t = 0.32, joints = {
			Head = { 0, 0, 0, 0.05, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.0, 0, -0.45 },
			RightLowerArm = { 0, 0, 0, 1.5, 0, 0 },
		} },
		{ t = 0.46, joints = {
			Head = { 0, 0, 0, 0.15, 0, 0 },
			RightUpperArm = { 0, 0, 0, 1.1, 0, -0.55 },
			RightLowerArm = { 0, 0, 0, 1.9, 0, 0 },
		} },
		{ t = 0.7, joints = "first" },
	},
}

Poses.MOVES = { "Slide", "Swing", "Crank", "Cast", "Reel", "Eat" }

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
	kfs.Loop = def.looped == true
	kfs.Priority = Enum.AnimationPriority[def.priority]
	local first = def.keyframes[1].joints
	for _, k in def.keyframes do
		local joints = k.joints == "first" and first or k.joints
		local kf = Instance.new("Keyframe")
		kf.Time = k.t
		-- (a partial animation only poses its keyed joints and the joints above them)
		local function needed(name: string): boolean
			if not def.partial or name == "HumanoidRootPart" or joints[name] then
				return true
			end
			for _, child in Poses.TREE[name] or {} do
				if needed(child) then
					return true
				end
			end
			return false
		end
		local function pose(name: string, parent)
			if not needed(name) then
				return
			end
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
