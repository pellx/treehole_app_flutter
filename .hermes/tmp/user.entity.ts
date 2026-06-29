import { Entity, Column, PrimaryColumn, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { DeviceEntity } from './device.entity';

@Entity('users')
export class UserEntity {
  @PrimaryColumn({ type: 'varchar', length: 64 })
  internal_token: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  display_id: string;

  @Column({ type: 'varchar', length: 128, nullable: true })
  external_token: string;

  @Column({ type: 'timestamp', nullable: true, name: 'display_id_changed_at' })
  display_id_changed_at: Date;

  @Column({ type: 'timestamp', nullable: true, name: 'external_token_changed_at' })
  external_token_changed_at: Date;

  @CreateDateColumn({ type: 'timestamp', name: 'created_at' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamp', name: 'updated_at' })
  updated_at: Date;

  @OneToMany(() => DeviceEntity, (device) => device.user)
  devices: DeviceEntity[];
}
