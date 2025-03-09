class GGAIControllerRioter extends GGAIController;

var float mDestinationOffset;
var kActorSpawnable destActor;

var ParticleSystemComponent mMindControlPSC;

var Actor mActorToAttack;
var float targetRadius;

var NPCAnimationInfo mDesiredAnimationInfo;
var float totalTime;

var bool isAgressive;
var int missCount;
var int maxMissAllowed;
var bool isArrived;

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;

	super.Possess(inPawn, bVehicleTransition);

	AddRioterEffect();

	mMyPawn.mStandUpDelay=3.0f;
	mMyPawn.mTimesKnockedByGoat=0.f;
	if(mMyPawn.mTimesKnockedByGoatStayDownLimit != 0)
	{
		mMyPawn.mTimesKnockedByGoatStayDownLimit=3.f;
	}

	mMyPawn.mProtectItems.Length=0;
	if(destActor == none)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " destActor=" $ destActor);
	destActor.SetLocation(mMyPawn.Location);
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	StandUp();
}

event UnPossess()
{
	RemoveRioterEffect();
	destActor.ShutDown();
	destActor.Destroy();
	super.UnPossess();
}

function AddRioterEffect()
{
	mMyPawn.mesh.AttachComponent(mMindControlPSC, 'Head');
	mMindControlPSC.ActivateSystem();
}

function RemoveRioterEffect()
{
	mMindControlPSC.DeactivateSystem();
	mMindControlPSC.KillParticlesForced();
	if(mMindControlPSC.Owner != none)
	{
		mMindControlPSC.Owner.DetachComponent(mMindControlPSC);
	}
}

event Tick( float deltaTime )
{
	Super.Tick( deltaTime );

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " state=" $ mCurrentState);
	//Kill destroyed rioters
	if(destActor != none)
	{
		if(mMyPawn == none || mMyPawn.bPendingDelete || mMyPawn.Controller != self)
		{
			UnPossess();
			Destroy();
			return;
		}
	}

	if(!mMyPawn.mIsRagdoll)
	{
		//Fix NPC with no collisions
		if(mMyPawn.CollisionComponent == none)
		{
			mMyPawn.CollisionComponent = mMyPawn.Mesh;
		}

		//Fix NPC rotation
		UnlockDesiredRotation();
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " attack " $ mActorToAttack);
		if(mActorToAttack != none)
		{
			Pawn.SetDesiredRotation( rotator( Normal2D( mActorToAttack.Location - Pawn.Location ) ) );
			mMyPawn.LockDesiredRotation( true );

			//Fix pawn stuck after attack
			if(!IsValidTarget(mActorToAttack) || !ActInRange(mActorToAttack))
			{
				EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 1");
			}
			else if(mCurrentState == '')
			{
				GotoState( 'ChasePawn' );
			}
		}
		else
		{
			//Fix random movement state
			if(mCurrentState != 'RandomMovement'
			&& mCurrentState != 'StartPanic'
			&& mCurrentState != 'Dancing')
			{
				//WorldInfo.Game.Broadcast(self, mMyPawn $ " no state detected");
				GoToState('RandomMovement');
			}

			if(IsZero(mMyPawn.Velocity))
			{
				if(isArrived && (mDesiredAnimationInfo == mMyPawn.mIdleAnimationInfo || !mMyPawn.isCurrentAnimationInfoStruct(mDesiredAnimationInfo)))
				{
					BeInsane();
				}

				if(!IsTimerActive( NameOf( StartRandomMovement ) ))
				{
					SetTimer(RandRange(1.0f, 10.0f), false, nameof( StartRandomMovement ) );
				}
			}
			else
			{
				if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo ) )
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );
				}
				mDesiredAnimationInfo=mMyPawn.mIdleAnimationInfo;
			}
		}
		// if waited too long to before reaching some place or some item, abandon
		totalTime = totalTime + (deltaTime * (mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo )?2:1));
		if(totalTime > 11.f)
		{
			totalTime=0.f;
			if(mActorToAttack != none)
			{
				mMyPawn.SetRagdoll(true);
				missCount++;//WorldInfo.Game.Broadcast(self, mMyPawn $ " missCount=" $ missCount);
			}
			else if(!isArrived)
			{
				mMyPawn.SetRagdoll(true);
			}
			EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 2");
		}
	}
	else
	{
		//Fix NPC not standing up
		if(!IsTimerActive( NameOf( StandUp ) )
		&& mMyPawn.mTimesKnockedByGoat<mMyPawn.mTimesKnockedByGoatStayDownLimit)
		{
			StartStandUpTimer();
		}

		//Kill drowning rioters
		if(mMyPawn.mInWater)
		{
			mMyPawn.Controller=none;
			UnPossess();
			Destroy();
		}
	}
}

// Trigger random animations and voices
function BeInsane()
{
	local NPCAnimationInfo musicAnimationInfo;
	local float duration;

	if(IsTimerActive(NameOf(BeInsane)))
	{
		ClearTimer(NameOf(BeInsane));
	}

	if(mActorToAttack != none)
		return;

	switch(Rand(5))
	{
		case 0:
			mDesiredAnimationInfo=mMyPawn.mPanicAtWallAnimationInfo;
			break;
		case 1:
			mDesiredAnimationInfo=mMyPawn.mApplaudAnimationInfo;
			break;
		case 2:
			mDesiredAnimationInfo=mMyPawn.mAngryAnimationInfo;
			break;
		case 3:
			mDesiredAnimationInfo=mMyPawn.mNoticeGoatAnimationInfo;
			break;
		case 4:
			mDesiredAnimationInfo=mMyPawn.mDanceAnimationInfo;
			break;
	}
	musicAnimationInfo=mDesiredAnimationInfo==mMyPawn.mDanceAnimationInfo?mMyPawn.mPanicAnimationInfo:mDesiredAnimationInfo;
	duration=mMyPawn.SetAnimationInfoStruct(mDesiredAnimationInfo, true);
	mMyPawn.PlaySoundFromAnimationInfoStruct(musicAnimationInfo);
	if(duration > 0 &&
	(mDesiredAnimationInfo == mMyPawn.mApplaudAnimationInfo
	|| mDesiredAnimationInfo == mMyPawn.mNoticeGoatAnimationInfo))
	{
		SetTimer(duration, , NameOf(BeInsane));
	}
}

function bool FindRandomActorToAttack()
{
	local Actor target, tmp;
	local array<Actor> visibleActors;
	local array<Actor> visibleKActors;
	local int size;

	foreach VisibleCollidingActors(class'Actor', tmp, mMyPawn.SightRadius, mMyPawn.Location)
	{
		if(GGPawn(tmp) == none && IsValidTarget(tmp))
		{
			if(IsValidTargetAndNotKactor(tmp))
			{
				visibleActors.AddItem(tmp);
			}
			else
			{
				visibleKActors.AddItem(tmp);
			}
		}
	}

	size=visibleActors.Length;
	if(size == 0)
	{
		size=visibleKActors.Length;
		if(size == 0 || Rand(2) > 0)// 50% chances to attack a random object
		{
			return false;
		}
		target=visibleKActors[Rand(size)];
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " attack " $ target $ " at " $ target.Location);
		//DrawDebugLine (mMyPawn.Location, target.Location, 0, 0, 0,);
	}
	else
	{
		target=visibleActors[Rand(size)];
	}

	EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 3");
	StartAttackingItem(mMyPawn.mProtectItems[0], target);
	return true;
}

function StartRandomMovement()
{
	local vector dest;
	local int OffsetX;
	local int OffsetY;

	if(mActorToAttack != none || mMyPawn.mIsRagdoll)
	{
		return;
	}
	mMyPawn.PlaySoundFromAnimationInfoStruct( mMyPawn.mAngryAnimationInfo );
	if(isAgressive && Rand(10) > 0 && FindRandomActorToAttack())// 90% chances to try to attack a breakable item
	{
		return;
	}
	if(!isAgressive)
	{
		missCount--;//WorldInfo.Game.Broadcast(self, mMyPawn $ " missCount=" $ missCount);
		if(missCount <= 0)
		{
			isAgressive=true;//WorldInfo.Game.Broadcast(self, mMyPawn $ " isAgressive");
			missCount=0;
		}
	}
	totalTime=-10.f;
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " start random movement");

	OffsetX = Rand(1000)-500;
	OffsetY = Rand(1000)-500;

	dest.X = mMyPawn.Location.X + OffsetX;
	dest.Y = mMyPawn.Location.Y + OffsetY;
	dest.Z = mMyPawn.Location.Z;

	destActor.SetLocation(dest);
	isArrived=false;
	//mMyPawn.SetDesiredRotation(rotator(Normal(dest -  mMyPawn.Location)));

}

function StartAttackingItem( ProtectInfo protectInformation, Actor threat )
{
	local float h;

	StopAllScheduledMovement();
	totalTime=0.f;

	mCurrentlyProtecting = protectInformation;

	mActorToAttack = threat;
	mActorToAttack.GetBoundingCylinder(targetRadius, h);

	StartLookAt( threat, 5.0f );

	GotoState( 'ChasePawn' );
}

function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat )
{
	local float h;

	mMyPawn.PlaySoundFromAnimationInfoStruct( mMyPawn.mAngryAnimationInfo );
	if(isAgressive && Rand(10) > 0 && FindRandomActorToAttack())// 90% chances to attack item instead
	{
		return;
	}
	else if(Rand(10) > 0 || !isAgressive)// 9% chances to do nothing and forget enemy
	{
		mVisibleGoats.RemoveItem(GGGoat(threat));
		mVisibleEnemies.RemoveItem(threat);
		return;
	}
	// else 1% chances to attack pawn

	StopAllScheduledMovement();
	totalTime=0.f;

	mCurrentlyProtecting = protectInformation;

	mPawnToAttack = threat;
	mActorToAttack = threat;
	mActorToAttack.GetBoundingCylinder(targetRadius, h);

	StartLookAt( threat, 5.0f );

	GotoState( 'ChasePawn' );
}

/**
 * Attacks mPawnToAttack using mMyPawn.mAttackMomentum
 * called when our pawn needs to protect and item from a given pawn
 */
function AttackPawn()
{
	super.AttackPawn();

	if(mPawnToAttack != none && GGGoat(mPawnToAttack) == none)
	{
		mPawnToAttack.TakeDamage(0, self, vect(0, 0, 0), vect(0, 0, 0), class'GGDamageTypeGTwo',, mMyPawn);
	}
	missCount=0;//WorldInfo.Game.Broadcast(self, mMyPawn $ " missCount=" $ missCount);
	//Fix pawn stuck after attack
	EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 4");
}

/**
 * Initiate the attack chain
 * called when our pawn needs to protect a given item
 */
function StartAttack( Pawn pawnToAttack )
{
	super.StartAttack(pawnToAttack);

	if(mPawnToAttack == pawnToAttack && !IsTimerActive(nameof( AttackPawn )))
	{
		AttackPawn();
	}
}

function StartBreaking( Actor actorToBreak )
{
	local float animLength;

	Pawn.SetDesiredRotation( rotator( Normal2D( actorToBreak.Location - Pawn.Location ) ) );

	mMyPawn.LockDesiredRotation( true );

	mActorToAttack = actorToBreak;

	animLength = mMyPawn.SetAnimationInfoStruct( mMyPawn.mAttackAnimationInfo );

	ClearTimer( nameof( BreakActor ) );

	mMyPawn.ZeroMovementVariables();

	SetTimer( animLength / 2, false, nameof( BreakActor ) );

	if(animLength == 0)
	{
		BreakActor();
	}
}

function BreakActor()
{
	local vector dir, hitLocation, direction;
	local float	ColRadius, ColHeight, animLength;

	StartLookAt( mActorToAttack, 5.0f );

	mActorToAttack.GetBoundingCylinder( ColRadius, ColHeight );
	dir = Normal( mActorToAttack.Location - mMyPawn.Location );
	hitLocation = mActorToAttack.Location - 0.5f * ( ColRadius + ColHeight ) *  dir;

	direction = Normal(vector( mMyPawn.Rotation ));
	mActorToAttack.TakeDamage(10000000, self, hitLocation, direction * 70000.f, class'GGDamageTypeAbility',, mMyPawn);

	animLength = mMyPawn.SetAnimationInfoStruct( mMyPawn.mAngryAnimationInfo );

	ClearTimer( nameof( DelayedGoToProtect ) );
	SetTimer( animLength, false, nameof( DelayedGoToProtect ) );

	mAttackIntervalInfo.LastTimeStamp = WorldInfo.TimeSeconds;
	missCount=0;//WorldInfo.Game.Broadcast(self, mMyPawn $ " missCount=" $ missCount);

	//Fix pawn stuck after attack
	EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 5");
}

state WaitingForLanding
{
	event LongFall()
	{
		mDidLongFall = true;
	}

	event NotifyPostLanded()
	{
		if( mDidLongFall || !CanReturnToOrginalPosition() )
		{
			if( mMyPawn.IsDefaultAnimationRestingOnSomething() )
			{
			    mMyPawn.mDefaultAnimationInfo =	mMyPawn.mIdleAnimationInfo;
			}

			mOriginalPosition = mMyPawn.Location;
		}

		mDidLongFall = false;

		StopLatentExecution();
		mMyPawn.ZeroMovementVariables();
		GoToState( 'RandomMovement', 'Begin',,true );
	}

Begin:
	mMyPawn.ZeroMovementVariables();
	WaitForLanding( 1.0f );
}

state RandomMovement extends MasterState
{
	event PawnFalling()
	{
		GoToState( 'WaitingForLanding',,,true );
	}

	/**
	 * Called by APawn::moveToward when the point is unreachable
	 * due to obstruction or height differences.
	 */
	event MoveUnreachable( vector AttemptedDest, Actor AttemptedTarget )
	{
		if( AttemptedDest == mOriginalPosition )
		{
			if( mMyPawn.IsDefaultAnimationRestingOnSomething() )
			{
			    mMyPawn.mDefaultAnimationInfo =	mMyPawn.mIdleAnimationInfo;
			}

			mOriginalPosition = mMyPawn.Location;
			mMyPawn.ZeroMovementVariables();

			StartRandomMovement();
		}
	}
Begin:
	mMyPawn.ZeroMovementVariables();
	while(mActorToAttack == none)
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " STATE OK!!!");
		if(VSize2D(destActor.Location - mMyPawn.Location) > mDestinationOffset)
		{
			MoveToward (destActor);
		}
		else
		{
			if(!isArrived)
			{
				isArrived=true;
			}
			MoveToward (mMyPawn,, mDestinationOffset);// Ugly hack to prevent "runnaway loop" error
		}
	}
	mMyPawn.ZeroMovementVariables();
}

state ChasePawn extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );

	while( VSize( mMyPawn.Location - mActorToAttack.Location ) - targetRadius > mMyPawn.mAttackRange || !ReadyToAttack() )
	{
		if( mActorToAttack == none )
		{
			ReturnToOriginalPosition();
			break;
		}

		MoveToward( mActorToAttack,, mDestinationOffset );
	}

	FinishRotation();
	GotoState( 'Attack' );
}

state Attack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	Focus = mActorToAttack;

	if(mPawnToAttack != none)
	{
		StartAttack( mPawnToAttack );
	}
	else
	{
		StartBreaking(mActorToAttack);
	}
	FinishRotation();
}

/**
 * Go back to where the position we spawned on
 */
function ReturnToOriginalPosition()
{
	GotoState( 'RandomMovement' );
}

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

/**
 * Picks up on Actor::MakeNoise within Pawn.HearingThreshold
 */
event HearNoise( float Loudness, Actor NoiseMaker, optional Name NoiseType )
{
	super.HearNoise( Loudness, NoiseMaker, NoiseType );

	if( NoiseType == 'Baa' )
	{
		EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 6");
	}
}

static function bool IsHuman(GGPawn gpawn)
{
	local GGAIControllerMMO AIMMO;

	if(InStr(string(gpawn.Mesh.PhysicsAsset), "CasualGirl_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "CasualMan_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "SportyMan_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "HeistNPC_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "Explorer_Physics") != INDEX_NONE)
	{
		return true;
	}
	else if(InStr(string(gpawn.Mesh.PhysicsAsset), "SpaceNPC_Physics") != INDEX_NONE)
	{
		return true;
	}
	AIMMO=GGAIControllerMMO(gpawn.Controller);
	if(AIMMO == none)
	{
		return false;
	}
	else
	{
		return AIMMO.PawnIsHuman();
	}
}

function bool IsValidEnemy( Pawn newEnemy )
{
	local GGNpc npc;
	local GGPawn gpawn;

	gpawn=GGPawn(newEnemy);
	npc=GGNpc(newEnemy);
	if(gpawn != none)
	{
		if(gpawn.mIsRagdoll || (npc != none && npc.mInWater))
		{
			return false;
		}
		return true;
	}
	return false;
}

function bool IsValidTargetAndNotKactor( Actor newEnemy )
{
	local Pawn pwn;
	local GGApexDestructibleActor apexDestAct;
	local GGExplosiveActorAbstract expAct;

	pwn=Pawn(newEnemy);
	apexDestAct=GGApexDestructibleActor(newEnemy);
	expAct=GGExplosiveActorAbstract(newEnemy);
	if(pwn != none)
	{
		return IsValidEnemy(pwn);
	}
	else if(apexDestAct != none && !apexDestAct.mIsFractured)
	{
		return true;
	}
	else if(expAct != none && !expAct.mIsExploding)
	{
		return true;
	}

	return false;
}

function bool IsValidTarget( Actor newEnemy )
{
	if(IsValidTargetAndNotKactor(newEnemy))
	{
		return true;
	}
	else if(GGKactor(newEnemy) != none)
	{
		return true;
	}

	return false;
}

/**
 * Helper functioner for determining if the goat is in range of uur sightradius
 * if other is not specified mLastSeenGoat is checked against
 */
function bool PawnInRange( optional Pawn other )
{
	local GGPawn gpawn;

	gpawn=GGPawn(other);

	if(gpawn == none)
	{
		return false;
	}
	else if(gpawn.mIsRagdoll)
	{
		return false;
	}
	else
	{
		return super.PawnInRange(gpawn);
	}

}

function bool ActInRange( optional Actor other )
{
	local float dist;
	local Pawn pwn;

	pwn=Pawn(other);
	if(pwn != none)
	{
		return PawnInRange(pwn);
	}

	dist = VSize( other.Location - mMyPawn.Location );
	return dist <= mMyPawn.SightRadius;
}

function ResumeDefaultAction()
{
	GoToState('RandomMovement');
}

function bool PawnUsesScriptedRoute()
{
	return false;
}

/**
 * Called when we are near an interaction item
 * Makes our pawn loook at a given actor and play a given animatiopn
 * Sets a timer to resume scripted route
 * @param intertactionInfo - Information struct for the a given interaction
 */
function StartInteractingWith( InteractionInfo intertactionInfo );

//--------------------------------------------------------------//
//			GGNotificationInterface								//
//--------------------------------------------------------------//

/**
 * Called when a trick was made
 */
function OnTrickMade( GGTrickBase trickMade );

/**
 * Called when an actor takes damage
 */
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum );

/**
 * Called when a kismet action is triggered
 */
function OnKismetActivated( SequenceAction activatedKismet );

/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	local GGPawn gpawn;

	gpawn = GGPawn( ragdolledActor );

	if( ragdolledActor == mMyPawn && isRagdoll )
	{
		if( IsTimerActive( NameOf( StopPointing ) ) )
		{
			StopPointing();
		}

		if( IsTimerActive( NameOf( StopLookAt ) ) )
		{
			StopLookAt();
		}

		if( mCurrentState == 'ProtectItem' )
		{
			ClearTimer( nameof( AttackPawn ) );
			ClearTimer( nameof( BreakActor ) );
			ClearTimer( nameof( DelayedGoToProtect ) );
		}
		StopAllScheduledMovement();
		StartStandUpTimer();
		UnlockDesiredRotation();
	}

	if( gpawn != none)
	{
		if( gpawn == mPawnToAttack )
		{
			EndAttack();//WorldInfo.Game.Broadcast(self, mMyPawn $ " EndAttack 7");
		}

		if( gpawn == mLookAtActor )
		{
			StopLookAt();
		}
	}
}

function EndAttack()
{
	super.EndAttack();
	mActorToAttack=none;
	mDesiredAnimationInfo=mMyPawn.mIdleAnimationInfo;
	if(isAgressive && missCount >= maxMissAllowed)
	{
		isAgressive=false;//WorldInfo.Game.Broadcast(self, mMyPawn $ "not isAgressive");
	}
}

function bool CanPawnInteract()
{
	return false;
}

/**
 * Called when an actor performs a manual
 */
function OnManual( Actor manualPerformer, bool isDoingManual, bool wasSuccessful );

/**
 * Called when an actor start/stop wall running.
 */
function OnWallRun( Actor runner, bool isWallRunning );

/**
 * Called when an actor performes a wall jump.
 */
function OnWallJump( Actor jumper );

//--------------------------------------------------------------//
//			End GGNotificationInterface							//
//--------------------------------------------------------------//

/**
 * Choose if we want to clap or point at the goat
 * if point initiate the timers etc for pointing
 */
function ApplaudGoat();

/**
 * Sets positional values for the mPointControl to make it point at the goat
 * Called by a timer started in ApplaudGoat
 */
function PointAtGoat();

/**
 * Stops any pointing logic
 */
function StopPointing();

/**
 * Helper function to determine if we should applaud a certain trick
 * Called when the goat has performed a trick
 * @param trickMade - The trick the goat performed
 */
function bool WantToApplaudTrick( GGTrickBase trickMade  )
{
	return false;
}

/**
 * Helper function to determine if we should applaud a certain kismet trick
 * Called when the goat has performed a trick
 * @param trickRelatedKismet - The trick the goat performed
 */
function bool WantToApplaudKismetTrick( GGSeqAct_GiveScore trickRelatedKismet )
{
	return false;
}

/**
 * Helper function to determine if our pawn is close to a interact item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_InteractionInfo - The info about the interact item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearInteractItem( PathNode currentlyAtNode, out InteractionInfo out_InteractionInfo )
{
	return false;
}

function bool ShouldApplaud()
{
	return false;
}

function bool ShouldNotice()
{
	return false;
}

DefaultProperties
{
	isAgressive=true
	maxMissAllowed=5

	mDestinationOffset=100.0f
	bIsPlayer=true

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)

	Begin Object class=ParticleSystemComponent Name=ParticleSystemComponent0
        Template=ParticleSystem'Zombie_Particles.Particles.MindControl_ParticleSystem'
		bAutoActivate=true
		bResetOnDetach=true
	End Object
	mMindControlPSC=ParticleSystemComponent0
}
