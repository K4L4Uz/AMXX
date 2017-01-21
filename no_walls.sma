#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

const WPN_KNIFE = 29;

const Float:g_fReverse = -1.0;
const Float:g_fFraction = 9999.0;

public plugin_init() {
    register_plugin( "No Shoot Walls", "0.0.1", "hornet" );

    RegisterHam( Ham_TraceAttack, "player", "fwdHamTraceAttack" );
}

public fwdHamTraceAttack( iVictim, iAttacker, Float:fDmg, Float:fDir[3], iPtr, iBits ) {
    if( iAttacker && get_user_weapon(iAttacker) != WPN_KNIFE ) {
        static Float:vStart[3], Float:vEnd[3], Float:fFrac, iTarget;

        get_tr2( iPtr, TR_vecEndPos, vEnd );
        get_tr2( iPtr, TR_flFraction, fFrac );

        nw_vec_mul_scalar( fDir, g_fReverse, fDir );
        nw_vec_mul_scalar( fDir, fFrac * g_fFraction, vStart );
        nw_vec_add( vStart, vEnd, vStart );

        iTarget = fm_trace_line( iVictim, vEnd, vStart, vEnd );

        if( !iTarget )
            return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

stock fm_trace_line( iVictim, const Float:vStart[3], const Float:vEnd[3], Float:vRet[3] ) {
    engfunc( EngFunc_TraceLine, vStart, vEnd, (iVictim == -1) ? 1 : 0, iVictim, 0 );

    static iEnt;
    iEnt = get_tr2( 0, TR_pHit );
    get_tr2( 0, TR_vecEndPos, vRet );

    return pev_valid(iEnt) ? iEnt : 0;
}

stock nw_vec_add( const Float:vOne[3], const Float:vTwo[3], Float:vOut[3] ) { 
    vOut[0] = vOne[0] + vTwo[0]; 
    vOut[1] = vOne[1] + vTwo[1]; 
    vOut[2] = vOne[2] + vTwo[2]; 
}

stock nw_vec_mul_scalar( const Float:vVec[3], Float:fScalar, Float:vOut[3] ) {
    vOut[0] = vVec[0] * fScalar; 
    vOut[1] = vVec[1] * fScalar; 
    vOut[2] = vVec[2] * fScalar; 
}

