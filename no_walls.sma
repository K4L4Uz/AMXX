#include <amxmodx>
#include <engine>
#include <reapi>

#define WPN_KNIFE 29

public plugin_init() {
    register_plugin( "No Shoot Walls", "0.0.1", "hornet" );

    RegisterHookChain( RG_CBasePlayer_TraceAttack, "fwdPlayerTraceAttack" );
}

public fwdPlayerTraceAttack( const id, attacker, Float:fDmg, Float:vDir[3], ptr, iBits ) {
    //get_member(get_member(id, m_pActiveItem), m_iId)
    if( attacker && get_user_weapon( attacker ) != WPN_KNIFE ) {
        static Float:vStart[ 3 ], Float:vEnd[ 3 ], Float:fFrac, iTarget;

        get_pmtrace( ptr, pmt_endpos, vStart );
        fFrac = get_pmtrace( ptr, pmt_fraction );

        nw_vec_mul_scalar( vDir, -1.0, vDir );
        nw_vec_mul_scalar( vDir, fFrac * 9999.0, vStart );
        nw_vec_add( vStart, vEnd, vStart );

        iTarget = trace_line( id, vEnd, vStart, vEnd );

        if( !iTarget )
            return HC_SUPERCEDE;
    }

    return HC_CONTINUE;
}

stock nw_vec_add( const Float:vOne[ ], const Float:vTwo[ ], Float:vOut[ ] ) { 
    vOut[ 0 ] = vOne[ 0 ] + vTwo[ 0 ]; 
    vOut[ 1 ] = vOne[ 1 ] + vTwo[ 1 ]; 
    vOut[ 2 ] = vOne[ 2 ] + vTwo[ 2 ]; 
}

stock nw_vec_mul_scalar( const Float:vVec[ ], Float:fScalar, Float:vOut[ ] ) {
    vOut[ 0 ] = vVec[ 0 ] * fScalar; 
    vOut[ 1 ] = vVec[ 1 ] * fScalar; 
    vOut[ 2 ] = vVec[ 2 ] * fScalar; 
} 
