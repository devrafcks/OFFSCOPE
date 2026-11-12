--!strict
--[[
	Joint — lê/escreve o "C0" de uma junta do personagem, seja ela Motor6D (rig clássico)
	ou AnimationConstraint (Avatar Joint Upgrade, padrão nos avatares R15 atuais).

	Motor6D:             Part0.CFrame * C0 * Transform = Part1.CFrame * C1
	AnimationConstraint: Attachment0.WorldCFrame * Transform = Attachment1.WorldCFrame
	→ o equivalente ao C0 é o CFrame do Attachment0 (relativo ao Part0).
]]

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

--[[
	Aplica a pose "hold" (C0 desejado) na junta, por frame.
	• Motor6D: C0 = hold (a animação continua compondo no Transform).
	• AnimationConstraint: o Animator recalcula o Transform a partir do rig original e
	  anularia qualquer mudança no Attachment0; então sobrescrevemos o próprio Transform
	  (chame em RunService.PreSimulation, depois da animação e antes da física).
]]
function Joint.ApplyHold(joint: Instance, base: CFrame, hold: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = hold
	elseif joint:IsA("AnimationConstraint") then
		joint.Transform = base:Inverse() * hold
	end
end

return Joint
