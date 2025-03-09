class AsylumComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var GGMutatorComponentSkyrim mSkyrimMutator;
var AudioComponent mAC;
var SoundCue mSpartaSound;

var float revolutionRadius;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		gMe.SetTimer(1.f, false, NameOf(FindSkyrimMutator), self);
	}
}

function FindSkyrimMutator()
{
	mSkyrimMutator=GGMutatorComponentSkyrim(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'GGMutatorComponentSkyrim', gMe.mCachedSlotNr));
}

function FixSpartaSound()
{
	if(mSkyrimMutator != none && gMe.Controller != none)
	{
		GGPlayerInput( PlayerController( gMe.Controller ).PlayerInput ).UnregisterKeyStateListner( mSkyrimMutator.KeyState );
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	FixSpartaSound();

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			if(!gMe.mIsRagdoll)
			{
				StartRevolution();
			}
		}

		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			if(mSkyrimMutator != none)
			{
				if( mAC == none || mAC.IsPendingKill() )
				{
					mAC = myMut.CreateAudioComponent( mSpartaSound, false );
				}
				if(mAC.isPlaying())
				{
					mAC.Stop();
				}
				mAC.Play();

				if(gMe.IsTimerActive(NameOf(ThisIsSparta), self))
				{
					gMe.ClearTimer(NameOf(ThisIsSparta), self);
				}
				gMe.SetTimer(2.5f, false, NameOf(ThisIsSparta), self);
			}
		}
	}
}

function ThisIsSparta()
{
	mSkyrimMutator.mForceSoundEffect=none;
	mSkyrimMutator.ForcePush(gMe);
	mSkyrimMutator.mForceSoundEffect=mSkyrimMutator.default.mForceSoundEffect;
}

function StartRevolution()
{
	local GGNpc npc;

	foreach gMe.CollidingActors( class'GGNpc', npc, revolutionRadius, gMe.Location )
	{
		if(npc.mIsRagdoll && class'GGAIControllerRioter'.static.IsHuman(npc))
		{
			if(GGAIControllerRioter(npc.Controller) != none)
			{
				npc.mTimesKnockedByGoat=0.f;
				npc.mTimesKnockedByGoatStayDownLimit=10.f;
			}
			else
			{
				MakeRioter(npc);
			}
		}
	}
}

function MakeRioter(GGNpc npc)
{
	local Controller oldController;
	local GGAIControllerRioter newController;

	oldController=npc.Controller;
	if(oldController != none)
	{
		oldController.Unpossess();
		if(PlayerController(oldController) == none)
		{
			oldController.Destroy();
		}
	}

	newController = gMe.Spawn (class'GGAIControllerRioter');
	npc.Controller=newController;
	newController.Possess(npc, false);
}

defaultproperties
{
	revolutionRadius=200.f

	mSpartaSound=SoundCue'AsylumSounds.SpartaSoundCue'
}