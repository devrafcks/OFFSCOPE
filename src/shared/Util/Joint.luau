--!strict

local Joint = {}

function Joint.Find(parent: Instance?, name: string): Instance?
	if not parent then
		return nil
	end
	local joint = parent:FindFirstChild(name)
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		return joint
	end
	return nil
end

function Joint.GetC0(joint: Instance): CFrame?
	if joint:IsA("Motor6D") then
		return joint.C0
	elseif joint:IsA("AnimationConstraint") then
		local attachment = joint.Attachment0
		return attachment and attachment.CFrame
	end
	return nil
end

function Joint.SetC0(joint: Instance, c0: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = c0
	elseif joint:IsA("AnimationConstraint") then
		local attachment = joint.Attachment0
		if attachment then
			attachment.CFrame = c0
		end
	end
end

function Joint.ApplyHold(joint: Instance, base: CFrame, hold: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = hold
	elseif joint:IsA("AnimationConstraint") then
		joint.Transform = base:Inverse() * hold
	end
end

return Joint
